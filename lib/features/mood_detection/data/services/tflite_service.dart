import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
// import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../../data/models/emotion_result.dart';
import 'emotion_recognizer.dart';

class tfliteService {
  static EmotionRecognizer? _recognizer;
  static bool _isInitialized = false;

  /// Initialize the TensorFlow Lite service with enhanced validation
  static Future<bool> initialize() async {
    try {
      print('🔧 Initializing EmotionRecognizer...');
      _recognizer = EmotionRecognizer();
      await _recognizer!.loadModel();
      _isInitialized = true;
      print('✅ EmotionRecognizer initialized successfully');
      return true;
    } catch (e) {
      print('❌ Error initializing EmotionRecognizer: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Analyze image for emotion detection
  static Future<EmotionResult> analyzeImage(File imageFile) async {
    if (!_isInitialized || _recognizer == null) {
      print('⚠️ EmotionRecognizer not initialized, using fallback');
      return _getFallbackResult();
    }
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Could not decode image');
      }
      final result = await _recognizer!.recognizeEmotion(image);
      return EmotionResult(
        dominantEmotion: result['emotion'] ?? 'unknown',
        confidence: (result['confidence'] ?? 0.0) * 1.0,
        allEmotions: Map<String, double>.from(
          (result['all_predictions'] ?? <String, double>{})
              .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
        timestamp: DateTime.now(),
        analysisType: 'tflite',
      );
    } catch (e) {
      print('❌ Error in EmotionRecognizer: $e');
      return _getFallbackResult();
    }
  }

  /// Fallback result when TFLite is not available
  static EmotionResult _getFallbackResult() {
    final emotions = <String, double>{
      'anger': 0.1,
      'disgust': 0.1,
      'fear': 0.1,
      'happiness': 0.15,
      'neutral': 0.4,
      'sadness': 0.1,
      'surprise': 0.05,
    };
    final dominantEmotion =
        emotions.entries.reduce((a, b) => a.value > b.value ? a : b);
    return EmotionResult(
      dominantEmotion: dominantEmotion.key,
      confidence: dominantEmotion.value,
      allEmotions: emotions,
      timestamp: DateTime.now(),
      analysisType: 'tflite_fallback',
    );
  }

  /// Run inference with Uint8List input (improved method for camera frames)
  // Deprecated: runInference is not supported in the new model integration.
  static Future<List<double>?> runInference(Uint8List inputImage) async {
    print('runInference is deprecated and not used.');
    return [0.1, 0.1, 0.1, 0.4, 0.1, 0.1, 0.1];
  }

  /// Dispose resources
  static void dispose() {
    try {
      _recognizer?.dispose();
      _recognizer = null;
      _isInitialized = false;
      print('✅ EmotionRecognizer disposed');
    } catch (e) {
      print('⚠️ Error disposing EmotionRecognizer: $e');
    }
  }

  /// Get current labels
  static List<String> get labels => [
        'anger',
        'disgust',
        'fear',
        'happiness',
        'neutral',
        'sadness',
        'surprise'
      ];
}
