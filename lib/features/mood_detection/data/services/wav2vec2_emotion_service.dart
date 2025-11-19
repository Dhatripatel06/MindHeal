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

  static final Wav2Vec2EmotionService _instance = Wav2Vec2EmotionService._internal();
  factory Wav2Vec2EmotionService() => _instance;
  static Wav2Vec2EmotionService get instance => _instance;
  Wav2Vec2EmotionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      print("🚀 Initializing Wav2Vec2EmotionService...");
      final ort = OnnxRuntime();
      _session = await ort.createSessionFromAsset('assets/models/wav2vec2_emotion.onnx');
      
      final labelsData = await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).map((l) => l.trim()).toList();
      
      _isInitialized = true;
      print("✅ Wav2Vec2EmotionService Initialized. Labels: $_labels");
    } catch (e) {
      print("❌ Error initializing Wav2Vec2 service: $e");
    }
  }

  /// 1. Parse WAV (Skip Header)
  /// 2. Convert to Float32
  /// 3. Standardize (Mean=0, Std=1) <- CRITICAL FOR ACCURACY
  Float32List _processAudioData(Uint8List bytes) {
    try {
      // --- 1. SKIP HEADER ---
      // Simple heuristic: Skip 44 bytes. 
      // If the file is small, it might be just a header.
      if (bytes.length < 100) return Float32List(0);
      
      // Finding the 'data' chunk is safer, but 44 is standard for the recorder package.
      int offset = 44;
      
      // --- 2. CONVERT TO FLOAT ---
      final audioData = bytes.sublist(offset);
      final int16List = audioData.buffer.asInt16List();
      final floatList = Float32List(int16List.length);
      
      // Calculate Mean and StdDev for Normalization
      double sum = 0.0;
      for (var sample in int16List) {
        sum += sample;
      }
      double mean = sum / int16List.length;

      double sumSqDiff = 0.0;
      for (var sample in int16List) {
        double diff = sample - mean;
        sumSqDiff += diff * diff;
      }
      // Prevent division by zero if audio is silence
      double std = sqrt(sumSqDiff / int16List.length);
      if (std < 1e-5) std = 1.0; 

      // --- 3. STANDARDIZE ---
      // Formula: (x - mean) / std
      for (int i = 0; i < int16List.length; i++) {
        floatList[i] = (int16List[i] - mean) / std;
      }

      return floatList;
    } catch (e) {
      print("Error processing audio: $e");
      return Float32List(0);
    }
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized) await initialize();
    if (_session == null) return EmotionResult.error("Model not loaded");

    try {
      final audioBytes = await audioFile.readAsBytes();
      final inputFloats = _processAudioData(audioBytes);
      
      if (inputFloats.isEmpty) return EmotionResult.error("Invalid audio file");

      // Create Tensor
      final shape = [1, inputFloats.length];
      final inputTensor = await OrtValue.fromList(inputFloats.toList(), shape);
      final inputName = _session!.inputNames.first;
      final inputs = {inputName: inputTensor};
      
      // Run Inference
      final outputs = await _session!.run(inputs);
      if (outputs == null || outputs.isEmpty) throw Exception("Empty output");

      // Get Logits
      final outputKey = _session!.outputNames.first;
      final outputOrt = outputs[outputKey] as OrtValue?;
      final outputList = await outputOrt!.asList();
      final logits = (outputList[0] as List).map((e) => (e as num).toDouble()).toList();

      // Softmax
      final expScores = logits.map((s) => exp(s)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final probs = expScores.map((s) => s / sumExp).toList();

      final allEmotions = <String, double>{};
      double maxScore = -1;
      int maxIndex = 0;

      for (int i = 0; i < probs.length; i++) {
        if (_labels != null && i < _labels!.length) {
          allEmotions[_labels![i]] = probs[i];
          print("📊 ${_labels![i]}: ${(probs[i]*100).toStringAsFixed(1)}%"); // Debug log
          
          if (probs[i] > maxScore) {
            maxScore = probs[i];
            maxIndex = i;
          }
        }
      }

      return EmotionResult(
        emotion: _labels![maxIndex],
        confidence: maxScore,
        allEmotions: allEmotions,
        timestamp: DateTime.now(),
        processingTimeMs: 0,
      );
    } catch (e) {
      return EmotionResult.error(e.toString());
    }
  }
}