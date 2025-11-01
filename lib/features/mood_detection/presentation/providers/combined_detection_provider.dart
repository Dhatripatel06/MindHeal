import 'dart:ui' show Rect;
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../data/models/emotion_result.dart';
import 'image_detection_provider.dart';
import 'audio_detection_provider.dart';

class CombinedDetectionProvider extends ChangeNotifier {
  final ImageDetectionProvider _imageProvider = ImageDetectionProvider();
  final AudioDetectionProvider _audioProvider = AudioDetectionProvider();

  bool _isAnalyzing = false;
  bool _isVisualEnabled = true;
  bool _isAudioEnabled = true;
  bool _isFusionEnabled = true;
  EmotionResult? _fusedResult;
  double _imageConfidence = 0.0;
  double _audioConfidence = 0.0;

  // Getters
  bool get isAnalyzing => _isAnalyzing;
  bool get isRecording => _audioProvider.isRecording;
  bool get isVisualEnabled => _isVisualEnabled;
  bool get isAudioEnabled => _isAudioEnabled;
  bool get isFusionEnabled => _isFusionEnabled;
  EmotionResult? get fusedResult => _fusedResult;
  EmotionResult? get lastImageResult => _imageProvider.currentResult;
  EmotionResult? get lastAudioResult => _audioProvider.lastResult;
  double get imageConfidence => _imageConfidence;
  double get audioConfidence => _audioConfidence;

  // ✅ FIXED: Convert List<Face> to List<Rect> - Now using working provider
  List<Rect> get detectedFaces => []; // Face detection not implemented in current provider

  Map<String, double> get imageEmotions => _imageProvider.currentResult?.allEmotions ?? {};
  List<double> get audioData => _audioProvider.audioData;

  // Rest of your existing methods...
  Future<void> startCombinedAnalysis() async {
    if (!_isVisualEnabled && !_isAudioEnabled) return;

    _isAnalyzing = true;
    notifyListeners();

    try {
      if (_isAudioEnabled) {
        await _audioProvider.startRecording();
      }
      _startAnalysisLoop();
    } catch (e) {
      debugPrint('Error starting combined analysis: $e');
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<void> stopAnalysis() async {
    _isAnalyzing = false;

    try {
      if (_audioProvider.isRecording) {
        await _audioProvider.stopRecording();
        if (_isAudioEnabled) {
          await _audioProvider.analyzeLastRecording();
        }
      }

      if (_isFusionEnabled &&
          _imageProvider.currentResult != null &&
          _audioProvider.lastResult != null) {
        _performFusion();
      }
    } catch (e) {
      debugPrint('Error stopping analysis: $e');
    } finally {
      notifyListeners();
    }
  }

  void _startAnalysisLoop() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_isAnalyzing) {
        _performPeriodicAnalysis();
        _startAnalysisLoop();
      }
    });
  }

  Future<void> _performPeriodicAnalysis() async {
    if (_isVisualEnabled && _imageProvider.currentResult != null) {
      _imageConfidence = _imageProvider.currentResult!.confidence;
    }

    if (_isAudioEnabled && _audioProvider.lastResult != null) {
      _audioConfidence = _audioProvider.lastResult!.confidence;
    }

    if (_isFusionEnabled && _imageConfidence > 0 && _audioConfidence > 0) {
      _performFusion();
    }

    notifyListeners();
  }

  void _performFusion() {
    final imageResult = _imageProvider.currentResult;
    final audioResult = _audioProvider.lastResult;

    if (imageResult == null || audioResult == null) return;

    final fusedEmotions = <String, double>{};
    final allEmotions = <String>{};
    allEmotions.addAll(imageResult.allEmotions.keys);
    allEmotions.addAll(audioResult.allEmotions.keys);

    for (final emotion in allEmotions) {
      final imageConfidence = imageResult.allEmotions[emotion] ?? 0.0;
      final audioConfidence = audioResult.allEmotions[emotion] ?? 0.0;

      final fusedConfidence = (imageConfidence * 0.6) + (audioConfidence * 0.4);
      fusedEmotions[emotion] = fusedConfidence;
    }

    final dominantEmotion =
        fusedEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);

    _fusedResult = EmotionResult(
      emotion: dominantEmotion.key,
      confidence: dominantEmotion.value,
      allEmotions: fusedEmotions,
      timestamp: DateTime.now(),
      processingTimeMs: 0, // Combined analysis doesn't have specific processing time
    );

    notifyListeners();
  }

  void toggleVisual(bool enabled) {
    _isVisualEnabled = enabled;
    notifyListeners();
  }

  void toggleAudio(bool enabled) {
    _isAudioEnabled = enabled;
    notifyListeners();
  }

  void toggleFusion(bool enabled) {
    _isFusionEnabled = enabled;
    notifyListeners();
  }

  Future<void> analyzeCameraFrame(File frameFile) async {
    if (_isVisualEnabled) {
      await _imageProvider.processImage(frameFile);
      if (_imageProvider.currentResult != null) {
        _imageConfidence = _imageProvider.currentResult!.confidence;
      }
      notifyListeners();
    }
  }

  void clearResults() {
    _fusedResult = null;
    _imageProvider.reset();
    _audioProvider.clearResults();
    notifyListeners();
  }
}
