// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';

// --- FIX 1: The correct import ---
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

// --- FIX 2: Remove path_provider imports, they are not needed ---
// import 'package:path_provider/path_provider.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;

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

  // --- FIX 3: This method is no longer needed ---
  // Future<String> _getModelPath() async { ... }

  Future<void> initialize() async {
    if (_isInitialized) {
      print("Wav2Vec2EmotionService already initialized.");
      return;
    }

    try {
      // --- FIX 4: Load session directly from asset ---
      final ort = OnnxRuntime();
      _session = await ort.createSessionFromAsset(
          'assets/models/wav2vec2_superb_er.onnx');

      // Load labels (this was already correct)
      final labelsData =
          await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print("Wav2Vec2EmotionService Initialized. Labels: $_labels");
    } catch (e) {
      print("Error initializing Wav2Vec2 service: $e");
      _isInitialized = false;
    }
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized || _session == null || _labels == null) {
      print("Wav2Vec2 service not initialized. Call initialize() from main.dart");
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

      final shape = [1, audioFloats.length];

      // --- FIX 5: Use correct API for tensor creation ---
      inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);

      final inputs = {'input': inputTensor};
      // --- FIX 6: Use correct API for run ---
      outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty || outputs['logits'] == null) {
        throw Exception(
            "Model output is null or empty, or 'logits' key is missing");
      }

      // --- FIX 7: Use correct API for getting output ---
      final outputValue = await outputs['logits']!.asList();
      if (outputValue == null || (outputValue as List).isEmpty) {
        throw Exception("Model output 'logits' is null or empty");
      }

      final scores = (outputValue as List).first.cast<double>();

      final allEmotions = <String, double>{};
      double maxScore = -double.infinity;
      int maxIndex = -1;

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
      // --- FIX 8: Remove all .release() calls ---
      // This package does not use manual .release()
    }
  }
}