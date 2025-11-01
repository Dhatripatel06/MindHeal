// lib/features/mood_detection/data/services/audio_processing_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioProcessingService {
  static final AudioProcessingService _instance = AudioProcessingService._internal();
  factory AudioProcessingService() => _instance;
  AudioProcessingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final StreamController<List<double>> _audioDataController = StreamController<List<double>>.broadcast();
  
  String? _recordingPath;
  Timer? _amplitudeTimer;
  DateTime? _startTime;

  Stream<List<double>> get audioDataStream => _audioDataController.stream;
  Stream<Duration> get recordingDurationStream {
    return Stream.periodic(const Duration(seconds: 1), (i) {
      if (_startTime == null) return Duration.zero;
      return DateTime.now().difference(_startTime!);
    });
  }

  Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    // Use a .wav extension for PCM data
    return '${dir.path}/mindheal_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
  }

  Future<void> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        _recordingPath = await _getFilePath();
        _startTime = DateTime.now();

        // --- CRITICAL: Record at 16kHz PCM for Wav2Vec2 ---
        const config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        );

        await _recorder.start(config, path: _recordingPath!);

        // Start polling for amplitude
        _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
          if (await _recorder.isRecording()) {
            final amplitude = await _recorder.getAmplitude();
            // Simulate waveform data from amplitude
            final audioData = List.generate(64, (index) => (amplitude.current) / 30.0 - 1.0 + (index % 2 == 0 ? 0.1 : -0.1));
            _audioDataController.add(audioData);
          } else {
            timer.cancel();
          }
        });
      } else {
        throw Exception("Microphone permission not granted.");
      }
    } catch (e) {
      print('Error starting recording: $e');
      throw Exception("Could not start recording.");
    }
  }

  Future<File?> stopRecording() async {
    _amplitudeTimer?.cancel();
    _startTime = null;
    try {
      final path = await _recorder.stop();
      if (path != null) {
        _recordingPath = path;
        return File(_recordingPath!);
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      return null;
    }
  }

  Future<void> playLastRecording() async {
    if (_recordingPath == null) {
      throw Exception('No recording available to play.');
    }
    try {
      await _player.setFilePath(_recordingPath!);
      await _player.play();
    } catch (e) {
      print('Error playing recording: $e');
      throw Exception("Could not play recording.");
    }
  }

  void clearRecording() {
    _recordingPath = null;
    _audioDataController.add([]); // Clear waveform
    _startTime = null;
    if (_player.playing) {
      _player.stop();
    }
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _audioDataController.close();
    _recorder.dispose();
    _player.dispose();
  }
}