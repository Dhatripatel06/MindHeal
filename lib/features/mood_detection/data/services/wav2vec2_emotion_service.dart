// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

// --- FIX 1: Correct FFmpeg Imports for your package ---
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';

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
      
      // --- FIX 2: Load the optimized single-file model directly from assets ---
      // (Ensure 'wav2vec2_emotion.onnx' is in your assets/models/ folder)
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

  /// Converts ANY audio/video file to 16kHz Mono WAV
  Future<File?> _convertToCompatibleWav(File inputFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/processed_audio.wav';
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      print("🔄 Converting ${inputFile.path}...");

      // FFmpeg command:
      // -y : Overwrite
      // -i : Input
      // -vn : No video
      // -acodec pcm_s16le : 16-bit Raw PCM
      // -ar 16000 : 16k Sample Rate
      // -ac 1 : Mono
      final command = '-y -i "${inputFile.path}" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print("✅ Audio conversion successful");
        return outputFile;
      } else {
        print("❌ Audio conversion failed. Logs: ${await session.getLogsAsString()}");
        return null;
      }
    } catch (e) {
      print("❌ Conversion Exception: $e");
      return null;
    }
  }

  Future<EmotionResult> analyzeAudio(File rawFile) async {
    if (!_isInitialized || _session == null) {
      await initialize();
      if (!_isInitialized) return EmotionResult.error("Model not ready.");
    }

    // 1. Convert file to WAV
    File? audioFile = await _convertToCompatibleWav(rawFile);
    
    if (audioFile == null) {
       return EmotionResult.error("Could not convert audio file.");
    }

    try {
      // 2. Read Bytes & Skip Header
      final audioBytes = await audioFile.readAsBytes();
      // Skip standard WAV header (44 bytes)
      if (audioBytes.length <= 44) return EmotionResult.error("Audio too short.");
      
      final pcmData = audioBytes.sublist(44);
      final pcm16 = pcmData.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      
      // 3. Normalize to [-1.0, 1.0]
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      // 4. Run Inference
      final shape = [1, audioFloats.length];
      final inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);
      final inputs = {'input': inputTensor};
      
      final outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty) {
        throw Exception("Model returned empty output");
      }

      // 5. Process Output
      // Get 'logits' (usually the first output)
      final outputKey = _session!.outputNames.first;
      // The plugin returns a list of batches
      final outputValue = await outputs[outputKey]!.asList();
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
      return EmotionResult.error(e.toString());
    }
  }
}