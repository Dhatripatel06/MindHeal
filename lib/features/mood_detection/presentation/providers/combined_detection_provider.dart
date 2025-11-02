// lib/features/mood_detection/presentation/providers/combined_detection_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/presentation/providers/audio_detection_provider.dart';
import 'package:mental_wellness_app/features/mood_detection/presentation/providers/image_detection_provider.dart';

class CombinedDetectionProvider extends ChangeNotifier {
  final ImageDetectionProvider _imageProvider;
  final AudioDetectionProvider _audioProvider;
  final GeminiAdviserService _geminiService;

  bool _isProcessing = false;
  String? _combinedAdvice;
  String? _lastError;
  EmotionResult? _lastCombinedResult;

  CombinedDetectionProvider(
    this._imageProvider,
    this._audioProvider,
    this._geminiService,
  );

  bool get isProcessing => _isProcessing;
  String? get combinedAdvice => _combinedAdvice;
  String? get lastError => _lastError;
  EmotionResult? get lastCombinedResult => _lastCombinedResult;

  bool get isAudioRecording => _audioProvider.isRecording;
  List<double> get audioData => _audioProvider.audioData;
  Duration get recordingDuration => _audioProvider.recordingDuration;
  bool get hasAudioRecording => _audioProvider.hasRecording;

  Future<void> startAudioRecording() async {
    await _audioProvider.startRecording();
  }

  Future<void> stopRecordingAndAnalyze() async {
    _isProcessing = true;
    _combinedAdvice = null;
    _lastError = null;
    _lastCombinedResult = null;
    notifyListeners();

    try {
      // 1. Stop audio recording (this also triggers audio analysis inside the audio provider)
      // --- *** FIX: The 'analyzeLastRecording' call is removed *** ---
      final audioFile = await _audioProvider.stopRecording();
      if (audioFile == null) {
        throw Exception("Audio recording failed or was cancelled.");
      }

      // 2. Get the results from the individual providers
      final imageResult = _imageProvider.lastResult;
      final audioResult = _audioProvider.lastResult; // <-- Get result from here

      if (imageResult == null) {
        throw Exception("Image analysis has not been performed.");
      }
      if (audioResult == null) {
        throw Exception("Audio analysis failed to produce a result.");
      }

      // 3. Combine the results
      _lastCombinedResult = _combineResults(imageResult, audioResult);
      
      // 4. Get combined advice
      final context = "Combined analysis. "
          "Visual Emotion: ${imageResult.emotion} (Conf: ${imageResult.confidence.toStringAsFixed(2)}). "
          "Audio Emotion: ${audioResult.emotion} (Conf: ${audioResult.confidence.toStringAsFixed(2)}). "
          "Audio Text: ${_audioProvider.friendlyResponse?.split('\n').first ?? 'N/A'}"; // Get transcribed text if available

      _combinedAdvice = await _geminiService.getEmotionalAdvice(
        detectedEmotion: _lastCombinedResult!.emotion,
        confidence: _lastCombinedResult!.confidence,
        additionalContext: context,
        language: _audioProvider.selectedLanguage, // Use language from audio provider
      );

    } catch (e) {
      _lastError = e.toString();
      print("Error in combined analysis: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  EmotionResult _combineResults(EmotionResult imageResult, EmotionResult audioResult) {
    // Simple combination logic: average the maps and find the highest
    final combinedMap = <String, double>{};

    // Add all keys from image result
    for (var entry in imageResult.allEmotions.entries) {
      combinedMap[entry.key.toLowerCase()] = (combinedMap[entry.key.toLowerCase()] ?? 0) + entry.value;
    }
    
    // Add all keys from audio result
    for (var entry in audioResult.allEmotions.entries) {
      combinedMap[entry.key.toLowerCase()] = (combinedMap[entry.key.toLowerCase()] ?? 0) + entry.value;
    }
    
    // Normalize (average)
    combinedMap.forEach((key, value) {
      combinedMap[key] = value / 2.0;
    });

    // Find the highest
    String dominantEmotion = 'neutral';
    double maxConfidence = 0.0;
    combinedMap.forEach((key, value) {
      if (value > maxConfidence) {
        maxConfidence = value;
        dominantEmotion = key;
      }
    });

    return EmotionResult(
      emotion: dominantEmotion,
      confidence: maxConfidence,
      allEmotions: combinedMap,
      timestamp: DateTime.now(),
      processingTimeMs: 0,
    );
  }

  void clearAll() {
    _imageProvider.clearResults();
    _audioProvider.clearRecording();
    _combinedAdvice = null;
    _lastError = null;
    _lastCombinedResult = null;
    notifyListeners();
  }
}