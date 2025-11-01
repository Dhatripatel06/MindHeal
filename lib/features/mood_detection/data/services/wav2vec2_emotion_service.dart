// lib/features/mood_detection/data/services/wav2vec2_emotion_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class Wav2Vec2EmotionService {
  OrtSession? _session;
  List<String>? _labels;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load the ONNX model
    final modelData = await rootBundle.load('assets/models/wav2vec2_superb_er.onnx');
    _session = OrtSession.fromBuffer(modelData.buffer.asUint8List(), OrtSessionOptions());

    // Load the labels
    final labelsData = await rootBundle.loadString('assets/models/wav2vec2_labels.txt');
    _labels = labelsData.split('\n').where((l) => l.isNotEmpty).toList();

    _isInitialized = true;
    print("Wav2Vec2EmotionService Initialized. Labels: $_labels");
  }

  Future<String> analyzeAudio(File audioFile) async {
    if (!_isInitialized || _session == null || _labels == null) {
      await initialize();
    }
    
    // --- IMPORTANT ---
    // Wav2Vec2 models require audio at a 16kHz sample rate.
    // The `record` package should be configured to record at 16kHz.
    // If you are using an audio file, it MUST be resampled to 16kHz first.
    // This example ASSUMES the File is a raw PCM Float32List at 16kHz.
    // A real implementation would need to read the audio file (e.g., .wav or .m4a)
    // and convert it. This is a non-trivial step.
    
    // For this example, let's assume the AudioProcessingService provides a
    // correctly formatted raw audio file.
    
    try {
      // 1. Read audio data
      // This part is highly dependent on your audio format.
      // Let's assume you've managed to get a Float32List of the raw waveform.
      // This is a placeholder for actual audio processing.
      // You will need a library to read the audio file and resample it.
      // For now, this will fail unless the audioFile is raw PCM.
      final audioBytes = await audioFile.readAsBytes();
      final audioFloats = audioBytes.buffer.asFloat32List(); // THIS IS LIKELY WRONG
      
      // TODO: Replace above with proper audio loading/resampling to 16kHz Float32List

      // 2. Prepare model input
      // This is a simplification. Check your model's exact input specs.
      // It likely expects [1, num_samples]
      final shape = [1, audioFloats.length];
      final inputTensor = OrtValueTensor.createTensor(audioFloats, shape);

      // 3. Run inference
      final inputs = {'input': inputTensor};
      final runOptions = OrtRunOptions();
      final outputs = await _session!.runAsync(inputs, runOptions);

      // 4. Process output
      final outputTensor = outputs[0]?.value as List<List<double>>?;
      if (outputTensor == null) {
        throw Exception("Model output is null");
      }

      // Output is likely [1, num_labels]
      final scores = outputTensor[0];
      double maxScore = -double.infinity;
      int maxIndex = -1;

      for (int i = 0; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIndex = i;
        }
      }

      inputTensor.release();
      runOptions.release();
      outputs.forEach((o) => o?.release());

      if (maxIndex != -1 && maxIndex < _labels!.length) {
        return _labels![maxIndex];
      } else {
        return "neutral"; // Default fallback
      }
    } catch (e) {
      print("Error during Wav2Vec2 inference: $e");
      print("This likely failed because the audio file was not a raw Float32List at 16kHz.");
      print("Please implement proper audio resampling.");
      return "neutral"; // Fallback on error
    }
  }
}

// ---
// **Critical Note on `analyzeAudio`:**
// The code above for reading the audio file is a placeholder. You CANNOT just read
// the bytes of an `.m4a` or `.wav` file and treat it as a `Float32List`.
// You must use a library to:
// 1. Read the audio file (e.g., `audioplayers`, `just_audio`).
// 2. Decode it to PCM data.
// 3. Resample it to 16kHz (if it's not already).
// 4. Convert it to `Float32List`.
//
// A simple way to bypass this for now is to configure your `record` package
// to record directly at 16kHz.
// In your `AudioProcessingService.startRecording`, configure the `Record` object:
//
// await _recorder.start(
//   const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000),
//   path: _filePath,
// );
//
// If you do this, the file will be raw 16-bit PCM, which is closer. You'd
// then read it as `Int16List` and convert to `Float32List` normalized between -1.0 and 1.0.
// ---