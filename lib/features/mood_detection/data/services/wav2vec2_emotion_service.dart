// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart'; // Make sure you have path_provider in pubspec.yaml

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

  /// Helper: Copy asset to a real file on the device
  Future<String> _copyAssetToFile(String assetPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${directory.path}/$fileName');

    // If file doesn't exist or is empty, copy it
    if (!await file.exists() || await file.length() == 0) {
      print("Copying model to ${file.path}...");
      final byteData = await rootBundle.load(assetPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));
    }
    return file.path;
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      print("Wav2Vec2EmotionService already initialized.");
      return;
    }

    try {
      print("🚀 Initializing Wav2Vec2EmotionService...");
      
      // 1. Initialize environment
      final ort = OnnxRuntime();

      // 2. Copy model from assets to a real file path
      final modelPath = await _copyAssetToFile('assets/models/wav2vec2_superb_er.onnx');
      
      // 3. Create session from that file path
      _session = await ort.createSessionFromPath(modelPath);

      // 4. Load labels
      final labelsData =
          await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print("✅ Wav2Vec2EmotionService Initialized. Labels: $_labels");
    } catch (e) {
      print("❌ Error initializing Wav2Vec2 service: $e");
      _isInitialized = false;
    }
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized || _session == null || _labels == null) {
      print("Wav2Vec2 service not initialized. Attempting to initialize...");
      await initialize();
      if (!_isInitialized || _session == null) {
        return EmotionResult.error("Wav2Vec2 model failed to load.");
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
      // Read and process audio
      final audioBytes = await audioFile.readAsBytes();
      final pcm16 = audioBytes.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      if (audioFloats.isEmpty) {
        print("Audio file is empty.");
        return fallbackResult;
      }

      final shape = [1, audioFloats.length];
      inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);

      final inputs = {'input': inputTensor};
      outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty) {
        throw Exception("Model returned empty output");
      }

      // Handle output - assuming 'logits' is the output name
      // You can check _session!.outputNames to be sure
      final outputKey = _session!.outputNames.first;
      final outputValue = await outputs[outputKey]!.asList();
      
      final scores = (outputValue as List).first.cast<double>();

      final allEmotions = <String, double>{};
      double maxScore = -double.infinity;
      int maxIndex = -1;

      // Softmax
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
    }
    // Note: flutter_onnxruntime manages memory automatically for basic tensors
  }
}