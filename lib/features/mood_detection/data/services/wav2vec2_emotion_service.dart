import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/audio_converter_service.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:wav/wav.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

// --- TOP LEVEL FUNCTION FOR ISOLATE (Must be outside the class) ---
List<double> _normalizeAudioTask(List<double> audio) {
  if (audio.isEmpty) return [];
  
  // 1. Calculate Mean
  double sum = 0.0;
  for (var x in audio) sum += x;
  double mean = sum / audio.length;

  // 2. Calculate Std Dev
  double sumSqDiff = 0.0;
  for (var x in audio) {
    double diff = x - mean;
    sumSqDiff += diff * diff;
  }
  double std = sqrt(sumSqDiff / audio.length);
  if (std < 1e-5) std = 1.0; // Prevent division by zero

  // 3. Apply Z-Score
  return audio.map((x) => (x - mean) / std).toList();
}

class Wav2Vec2EmotionService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioConverterService _converter = AudioConverterService();
  
  OrtSession? _session;
  List<String>? _labels;
  bool _isInitialized = false;
  bool _isRecording = false;
  Timer? _timer;
  Duration _recordDuration = Duration.zero;

  final StreamController<List<double>> _audioDataController = StreamController<List<double>>.broadcast();
  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();

  Stream<List<double>> get audioDataStream => _audioDataController.stream;
  Stream<Duration> get recordingDurationStream => _durationController.stream;

  static final Wav2Vec2EmotionService _instance = Wav2Vec2EmotionService._internal();
  factory Wav2Vec2EmotionService() => _instance;
  static Wav2Vec2EmotionService get instance => _instance;
  Wav2Vec2EmotionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      print("🚀 Initializing Wav2Vec2 Pipeline...");
      
      final ort = OnnxRuntime();
      // Initialize session options if needed for threading performance
      _session = await ort.createSessionFromAsset('assets/models/wav2vec2_emotion.onnx');
      
      final labelsData = await rootBundle.loadString('assets/models/audio_emotion_labels.txt');
      _labels = labelsData.split('\n')
          .where((l) => l.isNotEmpty)
          .map((l) => l.trim().toLowerCase())
          .toList();

      _isInitialized = true;
      print("✅ Wav2Vec2 Ready. Labels: $_labels");
    } catch (e) {
      print("❌ AI Init Error: $e");
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final String path = '${tempDir.path}/temp_recording_${DateTime.now().millisecondsSinceEpoch}.wav';

        const config = RecordConfig(
          encoder: AudioEncoder.wav, 
          sampleRate: 16000,
          numChannels: 1,
        );

        await _recorder.start(config, path: path);
        _isRecording = true;
        _recordDuration = Duration.zero;
        _startUpdates();
        print("🎙️ Recording started at 16kHz: $path");
      } else {
        print("⚠️ Microphone permission denied");
      }
    } catch (e) {
      print("❌ Start Recording Error: $e");
      _isRecording = false;
    }
  }

  Future<File?> stopRecording() async {
    _timer?.cancel();
    _timer = null;
    _isRecording = false;
    try {
      final path = await _recorder.stop();
      if (path != null) {
        print("🛑 Recording saved: $path");
        return File(path);
      }
      return null;
    } catch (e) {
      print("❌ Stop Recording Error: $e");
      return null;
    }
  }

  void _startUpdates() {
    const tick = Duration(milliseconds: 100);
    _timer?.cancel();
    _timer = Timer.periodic(tick, (timer) async {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      _recordDuration += tick;
      _durationController.add(_recordDuration);

      try {
        final amp = await _recorder.getAmplitude();
        final double normalized = pow(10, (amp.current / 20)).toDouble().clamp(0.0, 1.0);
        final random = Random();
        final List<double> visualData = List.generate(20, (index) {
          return (random.nextDouble() * 0.5 + 0.5) * normalized; 
        });
        _audioDataController.add(visualData);
      } catch (e) {
        // Ignore
      }
    });
  }

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    final startTime = DateTime.now();
    if (!_isInitialized) await initialize();
    if (_session == null) return EmotionResult.error("Model not loaded");

    File? workingFile;
    try {
      // 1. Convert (Fast check)
      workingFile = await _converter.ensureWavFormat(audioFile);
      print("📂 Parsing WAV: ${workingFile.path}");
      
      // 2. Parse WAV (Native async I/O)
      final wav = await Wav.readFile(workingFile.path);
      
      if (wav.channels.isEmpty) return EmotionResult.error("Empty audio file");
      if (wav.samplesPerSecond != 16000) {
        print("⚠️ Warning: Audio is ${wav.samplesPerSecond}Hz. Model expects 16000Hz.");
      }

      List<double> audioData = wav.channels[0].toList();
      if (audioData.length < 1000) return EmotionResult.error("Audio too short");

      // 3. HEAVY MATH: Run Z-Score Normalization in background Isolate
      // This fixes the "Skipped frames" and BufferQueue errors
      audioData = await compute(_normalizeInIsolate, audioData);

      // 4. ONNX Inference
      final shape = [1, audioData.length];
      final inputTensor = await OrtValue.fromList(audioData, shape);
      
      final inputName = _session!.inputNames.first;
      final inputs = {inputName: inputTensor};

      // Run inference (flutter_onnxruntime executes this on its own thread pool)
      final outputs = await _session!.run(inputs);
      if (outputs == null || outputs.isEmpty) throw Exception("No output from AI");

      // 5. Post-processing
      final outputKey = _session!.outputNames.first;
      final outputOrt = outputs[outputKey] as OrtValue?;
      
      // Safely extract list
      final rawOutput = await outputOrt!.asList();
      final logits = (rawOutput[0] as List).map((e) => (e as num).toDouble()).toList();

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
          allEmotions[label] = score;
          if (score > maxScore) {
            maxScore = score;
            maxIndex = i;
          }
        }
      }

      // Clean up temp file only if we created it
      if (workingFile.path != audioFile.path) {
        await workingFile.delete().catchError((_) {}); 
      }
      
      // Do NOT call release() on tensors manually if passing them causes issues, 
      // allow GC to handle it or rely on run() to clean up inputs.
      // inputTensor.release(); 

      final endTime = DateTime.now();
      final processingTime = endTime.difference(startTime).inMilliseconds;

      return EmotionResult(
        emotion: _labels![maxIndex],
        confidence: maxScore,
        allEmotions: allEmotions,
        timestamp: DateTime.now(),
        processingTimeMs: processingTime,
      );

    } catch (e) {
      print("❌ Analysis Error: $e");
      return EmotionResult.error("Analysis failed: ${e.toString()}");
    }
  }
  
  // Wrapper to match compute signature
  static List<double> _normalizeInIsolate(List<double> data) {
    return _normalizeAudioTask(data);
  }

  void dispose() {
    _timer?.cancel();
    _audioDataController.close();
    _durationController.close();
    _recorder.dispose();
    // _session?.release(); // Avoid manual release if causing crashes
  }
}