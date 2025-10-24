import 'dart:io';
import 'package:flutter/foundation.dart';
import '/features/mood_detection/data/models/emotion_result.dart';
import '/features/mood_detection/data/services/audio_processing_service.dart';

class AudioDetectionProvider extends ChangeNotifier {
  final AudioProcessingService _audioService = AudioProcessingService();
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  bool _isVoiceDetected = false;
  bool _hasRecording = false;
  List<double> _audioData = [];
  Duration _recordingDuration = Duration.zero;
  EmotionResult? _lastResult;

  // Getters
  bool get isRecording => _isRecording;
  bool get isAnalyzing => _isAnalyzing;
  bool get isVoiceDetected => _isVoiceDetected;
  bool get hasRecording => _hasRecording;
  List<double> get audioData => _audioData;
  Duration get recordingDuration => _recordingDuration;
  EmotionResult? get lastResult => _lastResult;

  Future<void> startRecording() async {
    try {
      await _audioService.startRecording();
      _isRecording = true;
      _hasRecording = false;
      _recordingDuration = Duration.zero;
      
      // Start listening to audio data stream
      _audioService.audioDataStream.listen((data) {
        _audioData = data;
        _isVoiceDetected = data.any((sample) => sample.abs() > 0.1);
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      await _audioService.stopRecording();
      _isRecording = false;
      _hasRecording = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
  }

  Future<void> analyzeLastRecording() async {
    if (!_hasRecording) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      final result = await _audioService.analyzeLastRecording();
      _lastResult = result;
    } catch (e) {
      debugPrint('Error analyzing recording: $e');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> analyzeAudioFile(File audioFile) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      final result = await _audioService.analyzeAudioFile(audioFile);
      _lastResult = result;
    } catch (e) {
      debugPrint('Error analyzing audio file: $e');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> playLastRecording() async {
    try {
      await _audioService.playLastRecording();
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  void clearRecording() {
    _audioData = [];
    _hasRecording = false;
    _lastResult = null;
    notifyListeners();
  }

  void clearResults() {
    _lastResult = null;
    notifyListeners();
  }
}
