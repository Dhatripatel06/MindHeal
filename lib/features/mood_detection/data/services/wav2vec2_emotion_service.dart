// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class Wav2Vec2EmotionService {
  OrtSession? _session;
  List<String>? _labels;
  bool _isInitialized = false;

  // --- START SINGLETON ---
  static final Wav2Vec2EmotionService _instance =
      Wav2Vec2EmotionService._internal();
  factory Wav2Vec2EmotionService() => _instance;
  static Wav2Vec2EmotionService get instance => _instance;
  Wav2Vec2EmotionService._internal();
  // --- END SINGLETON ---

  Future<void> initialize() async {
    // Only initialize if it hasn't been already
    if (_isInitialized) {
      print("Wav2Vec2EmotionService already initialized.");
      return;
    }
    try {
      // --- FIX 1: New initialization logic ---
      final ort = OnnxRuntime();
      final modelData =
          await rootBundle.load('assets/models/wav2vec2_superb_er.onnx');
      _session =
          await ort.createSessionFromBuffer(modelData.buffer.asUint8List());

      // --- FIX 3: Corrected the label file path ---
      final labelsData =
          await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print("Wav2Vec2EmotionService Initialized. Labels: $_labels");
    } catch (e) {
      print("Error initializing Wav2Vec2 service: $e");
      _isInitialized = false; // Ensure it's false on error
    }
  }

  /// Analyzes a 16kHz PCM audio file and returns an EmotionResult.
  Future<EmotionResult> analyzeAudio(File audioFile) async {
    // Check initialization status
    if (!_isInitialized || _session == null || _labels == null) {
      print("Wav2Vec2 service not initialized. Call initialize() from main.dart");
      // Try to initialize again just in case, but this is a fallback
      await initialize();
      if (!_isInitialized || _session == null || _labels == null) {
         return EmotionResult.error("Wav2Vec2 model is not ready.");
      }
    }

    final fallbackResult = EmotionResult(
      emotion: 'neutral',
      confidence: 1.0,
      allEmotions: {'neutral': 1.0},
      timestamp: DateTime.now(),
      processingTimeMs: 0,
    );

    OrtValue? inputTensor;
    Map<String, OrtValue>? outputs;

    try {
      // 1. Read audio data
      final audioBytes = await audioFile.readAsBytes();

      final pcm16 = audioBytes.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      if (audioFloats.isEmpty) {
        print("Audio file is empty, returning fallback.");
        return fallbackResult;
      }

      // 2. Prepare model input
      final shape = [1, audioFloats.length];
      
      // --- FIX 1: New tensor creation logic ---
      inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);

      // --- FIX 1: New run logic ---
      // Your model structure shows the input name is 'input'
      final inputs = {'input': inputTensor};
      outputs = await _session!.run(inputs);

      // 4. Process output
      if (outputs == null || outputs.isEmpty || outputs['logits'] == null) {
        throw Exception("Model output is null or empty, or 'logits' key is missing");
      }

      // --- FIX 1: New output processing logic ---
      // Your model structure shows 'logits' is [1, 4]
      // so asList() will return a List<List<dynamic>>
      final outputValue = await outputs['logits']!.asList();
      if (outputValue == null || (outputValue as List).isEmpty) {
         throw Exception("Model output 'logits' is null or empty");
      }

      // Get the first (and only) batch, and cast scores to double
      final scores = (outputValue as List).first.cast<double>();

      final allEmotions = <String, double>{};
      double maxScore = -double.infinity;
      int maxIndex = -1;

      // Apply softmax to get probabilities
      final expScores = scores.map((s) => exp(s)).toList();
      final sumExpScores = expScores.reduce((a, b) => a + b);
      final probabilities = expScores.map((s) => s / sumExpScores).toList();

      for (int i = 0; i < probabilities.length; i++) {
        if (i < _labels!.length) {
          allEmotions[_labels![i]] = probabilities[i];
          if (probabilities[i] > maxScore) {
            maxScore = probabilities[i];
            maxIndex = i;
          }
        }
      }

      if (maxIndex != -1) {
        return EmotionResult(
          emotion: _labels![maxIndex],
          confidence: maxScore,
          allEmotions: allEmotions,
          timestamp: DateTime.now(),
          processingTimeMs: 0,
        );
      } else {
        return fallbackResult;
      }
    } catch (e) {
      print("Error during Wav2Vec2 inference: $e");
      return fallbackResult;
    } finally {
      // --- FIX 1: New release logic ---
      inputTensor?.release();
      outputs?.values.forEach((o) => o.release());
    }
  }
}