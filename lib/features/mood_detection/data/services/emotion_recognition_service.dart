import 'dart:io';
import 'dart:async';
import 'tflite_emotion_service.dart';
import '../models/emotion_result.dart';

class EmotionRecognizer {
  final TFLiteEmotionService _tfliteService = TFLiteEmotionService();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Initialize the emotion recognizer
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('Initializing EmotionRecognizer...');
      await _tfliteService.loadModel();
      _isInitialized = true;
      print('EmotionRecognizer initialized successfully');
    } catch (e) {
      print('Failed to initialize EmotionRecognizer: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Recognize emotion from image file
  Future<EmotionResult> recognizeEmotion(File imageFile) async {
    if (!_isInitialized) {
      throw Exception('EmotionRecognizer not initialized. Call initialize() first.');
    }

    try {
      final startTime = DateTime.now();
      
      // Run inference
      final predictions = await _tfliteService.runInference(imageFile);
      
      // Find primary emotion
      String primaryEmotion = '';
      double maxConfidence = 0.0;
      
      predictions.forEach((emotion, confidence) {
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          primaryEmotion = emotion;
        }
      });
      
      final processingTime = DateTime.now().difference(startTime);
      
      return EmotionResult(
        emotion: primaryEmotion,
        confidence: maxConfidence,
        allEmotions: predictions,
        timestamp: DateTime.now(),
        processingTimeMs: processingTime.inMilliseconds,
      );
    } catch (e) {
      print('Error recognizing emotion: $e');
      rethrow;
    }
  }

  /// Recognize emotions from multiple images
  Future<List<EmotionResult>> recognizeEmotionBatch(List<File> imageFiles) async {
    if (!_isInitialized) {
      throw Exception('EmotionRecognizer not initialized. Call initialize() first.');
    }

    List<EmotionResult> results = [];
    
    for (final imageFile in imageFiles) {
      try {
        final result = await recognizeEmotion(imageFile);
        results.add(result);
      } catch (e) {
        print('Error processing ${imageFile.path}: $e');
        // Add error result
        results.add(EmotionResult(
          emotion: 'error',
          confidence: 0.0,
          allEmotions: {},
          timestamp: DateTime.now(),
          processingTimeMs: 0,
          error: e.toString(),
        ));
      }
    }
    
    return results;
  }

  /// Get emotion from detection result
  Future<String> detectEmotion(File imageFile) async {
    final result = await recognizeEmotion(imageFile);
    return result.emotion;
  }

  /// Get emotion with confidence
  Future<Map<String, dynamic>> detectEmotionWithConfidence(File imageFile) async {
    final result = await recognizeEmotion(imageFile);
    return {
      'emotion': result.emotion,
      'confidence': result.confidence,
      'all_predictions': result.allEmotions,
    };
  }

  /// Dispose resources
  void dispose() {
    _tfliteService.dispose();
    _isInitialized = false;
  }
}