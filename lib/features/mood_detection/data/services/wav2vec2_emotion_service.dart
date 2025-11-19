import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

// FFmpeg imports REMOVED completely. 
// We rely on the Record package to give us the correct format.

class Wav2Vec2EmotionService {
  OrtSession? _session;
  List<String>? _labels;
  bool _isInitialized = false;

  // --- SINGLETON ---
  static final Wav2Vec2EmotionService _instance =
      Wav2Vec2EmotionService._internal();
  factory Wav2Vec2EmotionService() => _instance;
  static Wav2Vec2EmotionService get instance => _instance;
  Wav2Vec2EmotionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print("🚀 Initializing Wav2Vec2EmotionService...");
      
      final ort = OnnxRuntime();
      
      // Load your SINGLE FILE optimized model
      // Ensure 'assets/models/wav2vec2_emotion.onnx' is the actual file name in assets
      _session = await ort.createSessionFromAsset('assets/models/wav2vec2_emotion.onnx');

      // Load Labels
      final labelsData =
          await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print("✅ Wav2Vec2EmotionService Initialized. Labels: ${_labels?.length}");
    } catch (e) {
      print("❌ Error initializing Wav2Vec2 service: $e");
      _isInitialized = false;
    }
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized || _session == null) {
      await initialize();
      if (!_isInitialized) return EmotionResult.error("Model not ready.");
    }

    // Note: We skip conversion because AudioProcessingService now records 
    // directly to WAV/16k/Mono.
    // Limitation: Uploaded MP3s from gallery might fail analysis without FFmpeg.
    
    try {
      // 1. Read Bytes
      final audioBytes = await audioFile.readAsBytes();
      
      // Skip standard WAV header (44 bytes)
      if (audioBytes.length <= 44) return EmotionResult.error("Audio too short.");
      
      // 2. Parse PCM Data
      final pcmData = audioBytes.sublist(44);
      final pcm16 = pcmData.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      
      // Normalize
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      if (audioFloats.isEmpty) return EmotionResult.error("Empty audio data.");

      // 3. Run Inference
      final shape = [1, audioFloats.length];
      final inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);
      
      // Dynamic Input Name
      final inputName = _session!.inputNames.first; 
      final inputs = {inputName: inputTensor};
      
      final outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty) {
        throw Exception("Model returned empty output");
      }

      // 4. Process Output
      final outputKey = _session!.outputNames.first;
      final outputOrtValue = outputs[outputKey] as OrtValue?;
      if (outputOrtValue == null) throw Exception("Output tensor missing");

      final outputList = await outputOrtValue.asList();
      final firstBatch = outputList[0] as List;
      final scores = firstBatch.map((e) => (e as num).toDouble()).toList();

      // 5. Softmax & Result
      final allEmotions = <String, double>{};
      double maxScore = -double.infinity;
      int maxIndex = -1;

      final expScores = scores.map((s) => exp(s)).toList();
      final sumExpScores = expScores.reduce((a, b) => a + b);
      final probabilities = expScores.map((s) => s / sumExpScores).toList();

      for (int i = 0; i < probabilities.length; i++) {
        if (_labels != null && i < _labels!.length) {
          allEmotions[_labels![i]] = probabilities[i];
          if (probabilities[i] > maxScore) {
            maxScore = probabilities[i];
            maxIndex = i;
          }
        }
      }

      if (maxIndex != -1 && _labels != null) {
        return EmotionResult(
          emotion: _labels![maxIndex],
          confidence: maxScore,
          allEmotions: allEmotions,
          timestamp: DateTime.now(),
          processingTimeMs: 0,
        );
      }
      
      return EmotionResult.error("Could not classify emotion");

    } catch (e) {
      print("❌ Inference error: $e");
      return EmotionResult.error("Analysis failed: ${e.toString()}");
    }
  }
}