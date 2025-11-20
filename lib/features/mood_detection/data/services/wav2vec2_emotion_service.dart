import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:wav/wav.dart'; // NEW: Robust WAV parsing

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
      print("🚀 Initializing Emotion AI...");
      final ort = OnnxRuntime();
      _session = await ort.createSessionFromAsset('assets/models/wav2vec2_emotion.onnx');
      
      // Ensure labels are loaded in the model's specific order
      // 0:neutral, 1:happy, 2:angry, 3:sad
      final labelsData = await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n')
          .where((l) => l.isNotEmpty)
          .map((l) => l.trim().toLowerCase())
          .toList();

      _isInitialized = true;
      print("✅ AI Ready. Labels: $_labels");
    } catch (e) {
      print("❌ AI Init Error: $e");
    }
  }

  /// Standardize audio (Z-Score: Mean=0, Std=1)
  /// This helps the model distinguish emotion from volume.
  List<double> _standardizeAudio(List<double> audio) {
    if (audio.isEmpty) return [];

    // 1. Calculate Mean
    double sum = 0.0;
    for (var x in audio) sum += x;
    double mean = sum / audio.length;

    // 2. Calculate Standard Deviation
    double sumSqDiff = 0.0;
    for (var x in audio) {
      double diff = x - mean;
      sumSqDiff += diff * diff;
    }
    double std = sqrt(sumSqDiff / audio.length);
    if (std < 1e-5) std = 1.0; // Avoid /0

    // 3. Apply Z-Score
    return audio.map((x) => (x - mean) / std).toList();
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    if (!_isInitialized) await initialize();
    if (_session == null) return EmotionResult.error("Model not loaded");

    try {
      print("📂 Reading file: ${audioFile.path}");
      
      // 1. Parse WAV using 'wav' package
      // This handles headers, bit-depth, and formats automatically
      final wav = await Wav.readFile(audioFile.path);
      
      // 2. Extract Channel 0 (Mono)
      if (wav.channels.isEmpty) return EmotionResult.error("Empty audio file");
      
      // 'wav' package gives us Float64List, we need List<double>
      List<double> audioData = wav.channels[0].toList();

      // 3. Pre-processing Checks
      // Resampling is hard in pure Dart, so we assume input is 16kHz (enforced by Recorder)
      if (wav.samplesPerSecond != 16000) {
        print("⚠️ Warning: Audio is ${wav.samplesPerSecond}Hz. Model expects 16000Hz.");
      }
      
      if (audioData.length < 1000) return EmotionResult.error("Audio too short");

      // 4. Standardization (Critical for Accuracy)
      audioData = _standardizeAudio(audioData);

      // 5. Create ONNX Tensor
      final shape = [1, audioData.length];
      final inputTensor = await OrtValue.fromList(audioData, shape);
      
      final inputName = _session!.inputNames.first;
      final inputs = {inputName: inputTensor};

      // 6. Run Inference
      final outputs = await _session!.run(inputs);
      if (outputs == null || outputs.isEmpty) throw Exception("No output from AI");

      // 7. Process Output
      final outputKey = _session!.outputNames.first;
      final outputOrt = outputs[outputKey] as OrtValue?;
      final outputList = await outputOrt!.asList();
      final logits = (outputList[0] as List).map((e) => (e as num).toDouble()).toList();

      // Softmax
      final expScores = logits.map((s) => exp(s)).toList();
      final sumExp = expScores.reduce((a, b) => a + b);
      final probs = expScores.map((s) => s / sumExp).toList();

      final allEmotions = <String, double>{};
      double maxScore = -1.0;
      int maxIndex = 0;

      for (int i = 0; i < probs.length; i++) {
        if (_labels != null && i < _labels!.length) {
          String label = _labels![i];
          double score = probs[i];
          
          // Debug output
          print("📊 $label: ${(score * 100).toStringAsFixed(1)}%");
          
          allEmotions[label] = score;
          if (score > maxScore) {
            maxScore = score;
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
      print("Analysis Error: $e");
      return EmotionResult.error("Could not process audio. Ensure it is a WAV file.");
    }
  }
}