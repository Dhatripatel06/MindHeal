import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class tfliteService {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;

  /// Initialize the TensorFlow Lite service with enhanced validation
  static Future<bool> initialize() async {
    try {
      print('🔧 Initializing TFLite service...');
      print('🤖 Initializing ResEmoteNet TFLite service...');

      // Try to load the model
      try {
        _interpreter = await Interpreter.fromAsset(
            'assets/models/fer2013_model_direct.tflite');

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
    try {
      final labelsData =
          await rootBundle.loadString('assets/models/labels.txt');
      _labels =
          labelsData.split('\n').where((line) => line.isNotEmpty).toList();
    } catch (e) {
      print('⚠️ Could not load labels, using default emotions');
      _labels = [
        'Angry',
        'Disgust',
        'Fear',
        'Happy',
        'Sad',
        'Surprise',
        'Neutral'
      ];
    }
  }

  /// Check if service is initialized
  static bool get isInitialized => _isInitialized;

  /// Analyze image for emotion detection
  static Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
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

      // Resize image to model input size (48x48 for FER2013)
      // Use cubic interpolation for better quality
      final resizedImage = img.copyResize(image,
          width: 48, height: 48, interpolation: img.Interpolation.cubic);

      // Convert to grayscale and normalize
      final input = _preprocessImage(resizedImage);

      // Run inference
      var output = List.filled(7, 0.0).reshape([1, 7]);
      _interpreter!.run(input, output);

      // Apply softmax to get proper probabilities
      final predictions = _applySoftmax(output[0].cast<double>());
      final result = _processResults(predictions);

      print(
          '✅ Emotion detection completed - Primary: ${result['primaryEmotion']} (${(result['confidence'] * 100).toStringAsFixed(1)}%)');
      return result;
    } catch (e) {
      print('❌ Error during emotion analysis: $e');
      return _getFallbackResult();
    }
  }

  /// Preprocess image for model input (FER2013 ResEmoteNet requirements)
  static List<List<List<List<double>>>> _preprocessImage(img.Image image) {
    // Convert to grayscale first
    final grayscaleImage = img.grayscale(image);

    final input = List.generate(
      1,
      (i) => List.generate(
        48,
        (y) => List.generate(
          48,
          (x) => List.generate(1, (c) {
            final pixel = grayscaleImage.getPixel(x, y);
            // Get the red channel value (same as gray value in grayscale image)
            final grayValue = img.getRed(pixel);
            // Normalize to [-1, 1] range as commonly used in ResNet-based models
            final normalizedValue = (grayValue / 127.5) - 1.0;
            return normalizedValue;
          }),
        ),
      ),
    );
    return input;
  }

  /// Apply softmax function to convert logits to probabilities
  static List<double> _applySoftmax(List<double> logits) {
    // Find max value for numerical stability
    double maxLogit = logits.reduce((a, b) => a > b ? a : b);

    // Calculate exp(x - max) for each element
    List<double> expValues = logits.map((x) => math.exp(x - maxLogit)).toList();

    // Calculate sum of all exp values
    double sumExp = expValues.reduce((a, b) => a + b);

    // Normalize to get probabilities
    return expValues.map((x) => x / sumExp).toList();
  }

  /// Process model output to emotion results with improved confidence handling
  static Map<String, dynamic> _processResults(List<double> predictions) {
    final emotionLabels = _labels ??
        ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral'];

    // Ensure we have the right number of predictions
    if (predictions.length != emotionLabels.length) {
      print(
          '⚠️ Prediction length (${predictions.length}) doesn\'t match emotion labels (${emotionLabels.length})');
    }

    // Find the emotion with highest confidence
    int maxIndex = 0;
    double maxConfidence = predictions[0];
    for (int i = 1; i < predictions.length && i < emotionLabels.length; i++) {
      if (predictions[i] > maxConfidence) {
        maxConfidence = predictions[i];
        maxIndex = i;
      }
    }

    // Create emotion confidence map with proper probabilities
    Map<String, double> emotionConfidences = {};
    for (int i = 0; i < predictions.length && i < emotionLabels.length; i++) {
      // Ensure confidence values are between 0 and 1
      double confidence = math.max(0.0, math.min(1.0, predictions[i]));
      emotionConfidences[emotionLabels[i]] = confidence;
    }

    // Calculate secondary emotion (second highest confidence)
    String secondaryEmotion = 'Neutral';
    double secondaryConfidence = 0.0;
    for (int i = 0; i < predictions.length && i < emotionLabels.length; i++) {
      if (i != maxIndex && predictions[i] > secondaryConfidence) {
        secondaryConfidence = predictions[i];
        secondaryEmotion = emotionLabels[i];
      }
    }

    // Determine if the prediction is confident enough
    bool isConfidentPrediction =
        maxConfidence > 0.4; // Minimum 40% confidence threshold

    return {
      'primaryEmotion': emotionLabels[maxIndex],
      'confidence': maxConfidence,
      'secondaryEmotion': secondaryEmotion,
      'secondaryConfidence': secondaryConfidence,
      'emotionConfidences': emotionConfidences,
      'isConfident': isConfidentPrediction,
      'timestamp': DateTime.now().toIso8601String(),
      'modelUsed': 'ResEmoteNet_FER2013',
    };
  }

  /// Fallback result when TFLite is not available
  static Map<String, dynamic> _getFallbackResult() {
    return {
      'primaryEmotion': 'Neutral',
      'confidence': 0.4,
      'emotionConfidences': {
        'Angry': 0.1,
        'Disgust': 0.1,
        'Fear': 0.1,
        'Happy': 0.15,
        'Sad': 0.1,
        'Surprise': 0.05,
        'Neutral': 0.4,
      },
      'timestamp': DateTime.now().toIso8601String(),
      'fallback': true,
    };
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

      // Resize and preprocess the image
      final resizedImage = img.copyResize(image,
          width: 48, height: 48, interpolation: img.Interpolation.cubic);

      // Apply the same preprocessing as analyzeImage
      final input = _preprocessImage(resizedImage);

      // Run inference
      var output = List.filled(7, 0.0).reshape([1, 7]);
      _interpreter!.run(input, output);

      // Apply softmax and return
      final predictions = _applySoftmax(output[0].cast<double>());
      return predictions;
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
