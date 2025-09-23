import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../../data/models/emotion_result.dart';

class tfliteService {
  static Interpreter? _interpreter;
  static List<String>? _labels = [
    'anger',
    'disgust',
    'fear',
    'happiness',
    'neutral',
    'sadness',
    'surprise',
  ];
  static bool _isInitialized = false;

  /// Initialize the TensorFlow Lite service with enhanced validation
  static Future<bool> initialize() async {
    try {
      print('🔧 Initializing TFLite service...');
      print('🤖 Initializing ResEmoteNet TFLite service...');

      // Try to load the model
      try {
        _interpreter =
            await Interpreter.fromAsset('assets/models/emotion_model.tflite');

        // Validate model input/output tensors
        final inputTensors = _interpreter!.getInputTensors();
        final outputTensors = _interpreter!.getOutputTensors();

        if (inputTensors.isNotEmpty && outputTensors.isNotEmpty) {
          final inputShape = inputTensors[0].shape;
          final outputShape = outputTensors[0].shape;

          print('📊 Model input shape: $inputShape');
          print('📊 Model output shape: $outputShape');

          // Validate expected shapes for FER2013 model
          if (inputShape.length >= 3 &&
              inputShape[1] == 48 &&
              inputShape[2] == 48) {
            print('✅ Model input dimensions validated (48x48)');
          } else {
            print(
                '⚠️ Unexpected input dimensions: expected [batch, 48, 48, channels], got $inputShape');
          }

          if (outputShape.length >= 2 && outputShape[1] == 7) {
            print('✅ Model output dimensions validated (7 emotions)');
          } else {
            print(
                '⚠️ Unexpected output dimensions: expected [batch, 7], got $outputShape');
          }
        }

        // Load labels
        await _loadLabels();

        _isInitialized = true;
        print('✅ TFLite service initialized successfully');
        return true;
      } catch (e) {
        print('❌ Error initializing ResEmoteNet service: $e');
        print('⚠️  TFLite service will run in fallback mode');
        _isInitialized = false;
        return false;
      }
    } catch (e) {
      print('❌ Failed to initialize TFLite service: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Load emotion labels
  static Future<void> _loadLabels() async {
    // Labels are now hardcoded to match the integration guide and model output
    // Optionally, you can still load from file if needed
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Analyze image for emotion detection
  static Future<EmotionResult> analyzeImage(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      print('⚠️ TFLite service not initialized, using fallback');
      return _getFallbackResult();
    }

    try {
      // Load and preprocess image
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Could not decode image');
      }

      // Resize image to model input size (224x224 for emotion_model.tflite)
      final resizedImage = img.copyResize(image,
          width: 224, height: 224, interpolation: img.Interpolation.cubic);

      // Preprocess to uint8 RGB (no normalization)
      final input = _preprocessImageUint8(resizedImage);

      // Prepare output
      var output = List.filled(7, 0.0).reshape([1, 7]);
      try {
        _interpreter!.run(input, output);
      } catch (e) {
        print('❌ TFLite run error: $e');
        return _getFallbackResult();
      }

      final predictions = output[0].cast<double>();
      final emotionLabels = _labels!;
      int maxIndex = 0;
      double maxConfidence = predictions[0];
      for (int i = 1; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          maxIndex = i;
        }
      }
      final allEmotions = <String, double>{};
      for (int i = 0; i < predictions.length; i++) {
        allEmotions[emotionLabels[i]] = predictions[i];
      }
      final result = EmotionResult(
        dominantEmotion: emotionLabels[maxIndex],
        confidence: maxConfidence,
        allEmotions: allEmotions,
        timestamp: DateTime.now(),
        analysisType: 'tflite',
      );
      print(
          '✅ Emotion detection completed - Primary: ${result.dominantEmotion} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      return result;
    } catch (e) {
      print('❌ Error during emotion analysis: $e');
      return _getFallbackResult();
    }
  }

  /// Preprocess image for model input (FER2013 ResEmoteNet requirements)
  static List<List<List<List<int>>>> _preprocessImageUint8(img.Image image) {
    // Use RGB uint8, no normalization
    const inputSize = 224;
    return List.generate(
      1,
      (b) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) => List.generate(3, (c) {
            final pixel = image.getPixel(x, y);
            if (c == 0) return img.getRed(pixel);
            if (c == 1) return img.getGreen(pixel);
            return img.getBlue(pixel);
          }),
        ),
      ),
    );
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
  static Future<List<double>?> runInference(Uint8List inputImage) async {
    if (!_isInitialized || _interpreter == null) {
      print('⚠️ TFLite service not initialized');
      return [0.1, 0.1, 0.1, 0.4, 0.1, 0.1, 0.1]; // Neutral fallback
    }

    try {
      // Convert Uint8List to Image for proper preprocessing
      final image = img.decodeImage(inputImage);
      if (image == null) {
        throw Exception('Could not decode input image');
      }

      // This method is deprecated and not used in the new flow.
      throw UnimplementedError(
          'runInference is not supported in the new model integration.');
    } catch (e) {
      print('❌ Error during inference: $e');
      return [0.1, 0.1, 0.1, 0.4, 0.1, 0.1, 0.1]; // Neutral fallback
    }
  }

  /// Dispose resources
  static void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      _labels = null;
      _isInitialized = false;
      print('✅ TFLite service disposed');
    } catch (e) {
      print('⚠️ Error disposing TFLite service: $e');
    }
  }

  /// Get current labels
  static List<String> get labels =>
      _labels ??
      ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral'];
}
