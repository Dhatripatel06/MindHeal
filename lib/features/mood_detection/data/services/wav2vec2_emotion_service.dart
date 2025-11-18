// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

// --- TEMPORARY: Removed FFmpeg imports to fix build ---
// import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';

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
      
      // Load the model from assets
      _session = await ort.createSessionFromAsset('assets/models/wav2vec2_emotion.onnx');

      // Load Labels
      final labelsData =
          await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print("✅ Wav2Vec2EmotionService Initialized.");
    } catch (e) {
      print("❌ Error initializing Wav2Vec2 service: $e");
      _isInitialized = false;
    }
  }

  /// Temporary Bypass: Just return the file as-is.
  /// When JitPack servers are fixed, we can add FFmpeg back.
  Future<File?> _convertToCompatibleWav(File inputFile) async {
    print("⚠️ FFmpeg disabled: Skipping conversion. Assuming file is valid WAV.");
    return inputFile;
  }

  Future<EmotionResult> analyzeAudio(File rawFile) async {
    if (!_isInitialized || _session == null) {
      await initialize();
      if (!_isInitialized) return EmotionResult.error("Model not ready.");
    }

    // 1. Get File (Conversion skipped)
    File? audioFile = await _convertToCompatibleWav(rawFile);
    
    try {
      // 2. Read Bytes
      final audioBytes = await audioFile!.readAsBytes();
      
      // Basic check for WAV header
      if (audioBytes.length <= 44) return EmotionResult.error("Audio too short.");
      
      // 3. Parse PCM Data
      // This assumes 16kHz Mono WAV input (standard for app recordings)
      // If you upload an MP3/MP4 manually, this might fail or give noise results
      // until we can add FFmpeg back.
      final pcmData = audioBytes.sublist(44);
      final pcm16 = pcmData.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      if (audioFloats.isEmpty) return EmotionResult.error("Empty audio data.");

      // 4. Run Inference
      final shape = [1, audioFloats.length];
      final inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);
      final inputs = {'input': inputTensor};
      
      final outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty) {
        throw Exception("Model returned empty output");
      }

      // 5. Process Output
      final outputKey = _session!.outputNames.first;
      final outputValue = await (outputs[outputKey] as OrtValue).asList();
      final firstBatch = outputValue[0] as List;
      final scores = firstBatch.map((e) => (e as num).toDouble()).toList();

      // 6. Softmax & Result
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