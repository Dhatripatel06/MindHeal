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

  /// Parses WAV to find audio data and normalizes volume for better accuracy
  Float32List _parseAndNormalizeWav(Uint8List bytes) {
    try {
      // 1. Find 'data' chunk to skip header
      int dataOffset = -1;
      for (int i = 0; i < min(bytes.length - 4, 2000); i++) {
        if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
          dataOffset = i + 8;
          break;
        }
      }
      
      if (dataOffset == -1) {
        print("⚠️ Header warning: 'data' chunk not found. Skipping standard 44 bytes.");
        dataOffset = 44; // Fallback
      }

      if (dataOffset >= bytes.length) return Float32List(0);

      // 2. Convert Bytes to Int16
      final audioData = bytes.sublist(dataOffset);
      final int16List = audioData.buffer.asInt16List();
      final floatList = Float32List(int16List.length);

      // 3. Find Max Amplitude for Normalization
      double maxAmp = 0.0;
      for (var sample in int16List) {
        double absSample = sample.abs().toDouble();
        if (absSample > maxAmp) maxAmp = absSample;
      }

      // 4. Normalize (Scale audio to -1.0 to 1.0 range)
      // If audio is too quiet, the model fails. This fixes it.
      double scaler = (maxAmp > 0) ? (1.0 / maxAmp) : 0.0; // Scale to max volume
      // Don't over-amplify noise if silence
      if (maxAmp < 100) scaler = 1.0 / 32768.0; 

      for (int i = 0; i < int16List.length; i++) {
        floatList[i] = int16List[i] * scaler; // Normalized
      }

      return floatList;
    } catch (e) {
      print("Error parsing WAV: $e");
      return Float32List(0);
    }
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized) await initialize();
    if (_session == null) return EmotionResult.error("Model not loaded");

    try {
      final audioBytes = await audioFile.readAsBytes();
      final audioFloats = _parseAndNormalizeWav(audioBytes);
      
      if (audioFloats.isEmpty) return EmotionResult.error("Audio file empty/invalid");

      // Inference
      final shape = [1, audioFloats.length];
      final inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);
      final inputName = _session!.inputNames.first;
      final inputs = {inputName: inputTensor};
      
      final outputs = await _session!.run(inputs);
      if (outputs == null || outputs.isEmpty) throw Exception("Empty output");

      final outputKey = _session!.outputNames.first;
      final outputOrt = outputs[outputKey] as OrtValue?;
      final outputList = await outputOrt!.asList();
      final scores = (outputList[0] as List).map((e) => (e as num).toDouble()).toList();

      // Softmax
      final expScores = scores.map((s) => exp(s)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final probs = expScores.map((s) => s / sumExp).toList();

      final allEmotions = <String, double>{};
      double maxScore = -1;
      int maxIndex = 0;

      for (int i = 0; i < probs.length; i++) {
        if (_labels != null && i < _labels!.length) {
          allEmotions[_labels![i]] = probs[i];
          print("Model Output -> ${_labels![i]}: ${(probs[i]*100).toStringAsFixed(1)}%");
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