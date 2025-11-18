// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

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

  /// Copies the asset to a local file so the C++ ONNX runtime can load it.
  Future<String> _copyAssetToFile(String assetPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${directory.path}/$fileName');

    // Always overwrite to ensure we use the latest model version
    if (await file.exists()) {
      await file.delete();
    }

    print("📦 Copying model to storage: ${file.path}...");
    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    ), flush: true);
    
    return file.path;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print("🚀 Initializing Wav2Vec2EmotionService...");
      
      final ort = OnnxRuntime();

      // --- FIX: Load the NEW optimized single-file model ---
      final modelPath = await _copyAssetToFile('assets/models/wav2vec2_emotion_fp16.onnx');
      
      // Create session from the physical file
      _session = await ort.createSession(modelPath);

      // Load labels
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

  /// Converts input audio/video to 16kHz Mono WAV for the model
  Future<File?> _convertToCompatibleWav(File inputFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/processed_audio.wav';
      final outputFile = File(outputPath);

      if (await outputFile.exists()) {
        await outputFile.delete();
      }

      // FFmpeg: Convert to PCM 16-bit, 16000Hz, Mono
      final command = '-y -i "${inputFile.path}" -vn -acodec pcm_s16le -ar 16000 -ac 1 "$outputPath"';
      
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return outputFile;
      } else {
        print("❌ FFmpeg Error: ${await session.getLogsAsString()}");
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
      if (!_isInitialized) return EmotionResult.error("Model failed to initialize.");
    }

    // 1. Convert file to WAV
    File? audioFile = await _convertToCompatibleWav(rawFile);
    if (audioFile == null) return EmotionResult.error("Audio conversion failed.");

    try {
      // 2. Read Bytes & Skip Header
      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.length <= 44) return EmotionResult.error("Audio file empty.");

      // 3. Normalize Audio
      final pcmData = audioBytes.sublist(44); // Skip WAV header
      final pcm16 = pcmData.buffer.asInt16List();
      final audioFloats = Float32List(pcm16.length);
      
      for (int i = 0; i < pcm16.length; i++) {
        audioFloats[i] = pcm16[i] / 32768.0;
      }

      // 4. Inference
      final shape = [1, audioFloats.length];
      final inputTensor = await OrtValue.fromList(audioFloats.toList(), shape);
      final inputs = {'input': inputTensor};
      
      final outputs = await _session!.run(inputs);

      if (outputs == null || outputs.isEmpty) throw Exception("Empty model output");

      // 5. Process Results
      final outputList = await (outputs.values.first as OrtValue).asList();
      final scoresList = outputList[0] as List; // First batch
      final scores = scoresList.map((e) => (e as num).toDouble()).toList();

      // Softmax
      final expScores = scores.map((s) => exp(s)).toList();
      final sumExpScores = expScores.reduce((a, b) => a + b);
      final probabilities = expScores.map((s) => s / sumExpScores).toList();

      final allEmotions = <String, double>{};
      double maxScore = -double.infinity;
      int maxIndex = -1;

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
      
      return EmotionResult.error("Classification failed");

    } catch (e) {
      print("❌ Inference Error: $e");
      return EmotionResult.error(e.toString());
    }
  }
}