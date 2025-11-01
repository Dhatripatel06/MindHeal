import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// TensorFlow Lite emotion detection service
/// Model specifications:
/// - Input: serving_default_sequential_5_input:0, float32[-1,224,224,3]
/// - Output: StatefulPartitionedCall:0, float32[-1,3]
/// - 3 emotion classes from labels.txt
class TFLiteEmotionService {
  static const String MODEL_PATH = 'assets/models/model_unquant.tflite';
  static const String LABELS_PATH = 'assets/models/labels.txt';
  static const int INPUT_WIDTH = 224;
  static const int INPUT_HEIGHT = 224;
  static const int INPUT_CHANNELS = 3;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Get the list of emotion labels
  List<String> get labels => List.unmodifiable(_labels);

  /// Initialize the TFLite model and load labels
  Future<void> loadModel() async {
    if (_isInitialized) return;

    try {
      print('🚀 Loading TFLite emotion detection model...');

      // Load the model
      await _loadTFLiteModel();

      // Load emotion labels
      await _loadLabels();

      // Validate model configuration
      _validateModel();

      _isInitialized = true;
      print('✅ TFLite emotion detection service initialized successfully');
      print('📋 Loaded ${_labels.length} emotion classes: $_labels');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize TFLite emotion detection service: $e');
      print('📍 Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Load the TensorFlow Lite model
  Future<void> _loadTFLiteModel() async {
    try {
      // Load model from assets
      final modelData = await rootBundle.load(MODEL_PATH);
      final modelBuffer = modelData.buffer.asUint8List();

      // Configure interpreter options for optimal performance
      final options = InterpreterOptions()
        ..threads = 2; // Use 2 threads for better performance

      // Create interpreter
      _interpreter = Interpreter.fromBuffer(modelBuffer, options: options);

      print('🔧 Model loaded successfully');
      _printModelInfo();
    } catch (e) {
      print('❌ Error loading TFLite model: $e');
      // Fallback: try without optimizations
      try {
        final modelData = await rootBundle.load(MODEL_PATH);
        final modelBuffer = modelData.buffer.asUint8List();
        _interpreter = Interpreter.fromBuffer(modelBuffer);
        print('⚠️ Model loaded with fallback configuration (no optimizations)');
      } catch (fallbackError) {
        print('❌ Fallback model loading also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Load emotion labels from assets
  Future<void> _loadLabels() async {
    try {
      final labelsData = await rootBundle.loadString(LABELS_PATH);
      _labels = labelsData
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (_labels.isEmpty) {
        throw Exception('No labels found in $LABELS_PATH');
      }

      print('📋 Loaded ${_labels.length} emotion labels');
    } catch (e) {
      print('❌ Error loading labels: $e');
      rethrow;
    }
  }

  /// Print model information for debugging
  void _printModelInfo() {
    if (_interpreter == null) return;

    try {
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('📊 Model Information:');
      print('   Input tensors: ${inputTensors.length}');
      for (int i = 0; i < inputTensors.length; i++) {
        final tensor = inputTensors[i];
        print('     [$i] ${tensor.name}: ${tensor.shape} (${tensor.type})');
      }

      print('   Output tensors: ${outputTensors.length}');
      for (int i = 0; i < outputTensors.length; i++) {
        final tensor = outputTensors[i];
        print('     [$i] ${tensor.name}: ${tensor.shape} (${tensor.type})');
      }
    } catch (e) {
      print('⚠️ Could not print model info: $e');
    }
  }

  /// Validate that the model matches expected specifications
  void _validateModel() {
    if (_interpreter == null) {
      throw Exception('Interpreter not initialized');
    }

    try {
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      // Validate input tensor
      if (inputTensors.isEmpty) {
        throw Exception('Model has no input tensors');
      }

      final inputTensor = inputTensors[0];
      final inputShape = inputTensor.shape;

      // Expected: [-1, 224, 224, 3] or [1, 224, 224, 3]
      if (inputShape.length != 4) {
        throw Exception('Expected 4D input tensor, got ${inputShape.length}D');
      }

      if (inputShape[1] != INPUT_HEIGHT ||
          inputShape[2] != INPUT_WIDTH ||
          inputShape[3] != INPUT_CHANNELS) {
        throw Exception(
            'Expected input shape [batch, $INPUT_HEIGHT, $INPUT_WIDTH, $INPUT_CHANNELS], '
            'got $inputShape');
      }

      // Validate output tensor
      if (outputTensors.isEmpty) {
        throw Exception('Model has no output tensors');
      }

      final outputTensor = outputTensors[0];
      final outputShape = outputTensor.shape;

      // Expected: [-1, num_classes] or [1, num_classes]
      if (outputShape.length != 2) {
        throw Exception(
            'Expected 2D output tensor, got ${outputShape.length}D');
      }

      if (outputShape[1] != _labels.length) {
        throw Exception(
            'Output tensor has ${outputShape[1]} classes but labels file has ${_labels.length} labels');
      }

      print('✅ Model validation passed');
    } catch (e) {
      print('❌ Model validation failed: $e');
      rethrow;
    }
  }

  /// Run inference on an image file
  Future<Map<String, double>> runInference(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      throw Exception('Service not initialized. Call loadModel() first.');
    }

    try {
      print('🔍 Running emotion inference on: ${imageFile.path}');

      // Preprocess the image
      final inputData = await _preprocessImage(imageFile);

      // Prepare output buffer
      final outputShape = _interpreter!.getOutputTensors()[0].shape;
      final numClasses = outputShape[1];
      final outputData = List.filled(numClasses, 0.0).reshape([1, numClasses]);

      // Run inference
      final stopwatch = Stopwatch()..start();
      _interpreter!.run(inputData, outputData);
      stopwatch.stop();

      print('⏱️ Inference completed in ${stopwatch.elapsedMilliseconds}ms');

      // Post-process results
      final predictions = _postprocessOutput(outputData[0]);

      print('🎯 Emotion predictions: ${_formatPredictions(predictions)}');

      return predictions;
    } catch (e) {
      print('❌ Error running inference: $e');
      rethrow;
    }
  }

  /// Preprocess image for model input
  Future<List<List<List<List<double>>>>> _preprocessImage(
      File imageFile) async {
    try {
      // Read and decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to model input size
      final resizedImage = img.copyResize(
        image,
        width: INPUT_WIDTH,
        height: INPUT_HEIGHT,
        interpolation: img.Interpolation.cubic,
      );

      // Convert to normalized float32 tensor [1, 224, 224, 3]
      final input = List.generate(
        1,
        (b) => List.generate(
          INPUT_HEIGHT,
          (h) => List.generate(
            INPUT_WIDTH,
            (w) => List.generate(
              INPUT_CHANNELS,
              (c) {
                final pixel = resizedImage.getPixel(w, h);
                double value;
                switch (c) {
                  case 0:
                    value = pixel.r.toDouble();
                    break;
                  case 1:
                    value = pixel.g.toDouble();
                    break;
                  case 2:
                    value = pixel.b.toDouble();
                    break;
                  default:
                    value = 0.0;
                }
                // Normalize to [0, 1] range (typical for most models)
                return value / 255.0;
              },
            ),
          ),
        ),
      );

      return input;
    } catch (e) {
      print('❌ Error preprocessing image: $e');
      rethrow;
    }
  }

  /// Post-process model output to get emotion predictions
  Map<String, double> _postprocessOutput(List<double> outputData) {
    try {
      // Apply softmax to convert logits to probabilities
      final predictions = _applySoftmax(outputData);

      // Create emotion -> confidence map
      final emotionMap = <String, double>{};
      for (int i = 0; i < predictions.length && i < _labels.length; i++) {
        emotionMap[_labels[i]] = predictions[i];
      }

      return emotionMap;
    } catch (e) {
      print('❌ Error post-processing output: $e');
      rethrow;
    }
  }

  /// Apply softmax activation to convert logits to probabilities
  List<double> _applySoftmax(List<double> logits) {
    // Find max value for numerical stability
    final maxLogit = logits.reduce(math.max);

    // Compute exp(logit - max_logit)
    final expValues =
        logits.map((logit) => math.exp(logit - maxLogit)).toList();

    // Compute sum of exponentials
    final sumExp = expValues.reduce((a, b) => a + b);

    // Normalize to get probabilities
    return expValues.map((exp) => exp / sumExp).toList();
  }

  /// Format predictions for logging
  String _formatPredictions(Map<String, double> predictions) {
    return predictions.entries
        .map((entry) =>
            '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%')
        .join(', ');
  }

  /// Get the dominant emotion from predictions
  String getDominantEmotion(Map<String, double> predictions) {
    if (predictions.isEmpty) return 'unknown';

    return predictions.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get confidence score for the dominant emotion
  double getDominantConfidence(Map<String, double> predictions) {
    if (predictions.isEmpty) return 0.0;

    return predictions.values.reduce(math.max);
  }

  /// Dispose resources
  void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      _labels.clear();
      _isInitialized = false;
      print('🗑️ TFLite emotion service disposed');
    } catch (e) {
      print('⚠️ Error disposing TFLite service: $e');
    }
  }
}
