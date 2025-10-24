import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
// Import the onnxruntime package
import 'package:onnxruntime/onnxruntime.dart';

import '../../../data/models/emotion_result.dart';

class OnnxEmotionService {
  static const String _modelAssetPath =
      'assets/models/enet_b0_8_best_afew.onnx';
  static const String _labelsAssetPath = 'assets/models/labels.txt';
  // Model specifications
  static const int _inputWidth = 224;
  static const int _inputHeight = 224;
  static const int _inputChannels = 3;
  // The model's input shape [batch_size, channels, height, width]
  static final _inputShape = [1, _inputChannels, _inputHeight, _inputWidth];

  // ImageNet normalization parameters (used in EfficientNet-B0)
  static const List<double> _meanImageNet = [0.485, 0.456, 0.406];
  static const List<double> _stdImageNet = [0.229, 0.224, 0.225];

  final Logger _logger = Logger();

  // Core ONNX Runtime components
  static OrtEnv? _env;
  static OrtSession? _session;

  List<String> _emotionClasses = [];
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Performance tracking
  final List<double> _inferenceTimes = [];
  int _totalInferences = 0;

  // Singleton pattern
  static OnnxEmotionService? _instance;
  static OnnxEmotionService get instance {
    _instance ??= OnnxEmotionService._internal();
    return _instance!;
  }

  OnnxEmotionService._internal();

  /// Initialize the emotion detection service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isInitializing) {
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }

    _isInitializing = true;
    _logger.i('Initializing ONNX Emotion Service...');

    try {
      // Load emotion classes from labels.txt
      await _loadEmotionClasses();

      // Initialize ONNX Runtime
      await _initializeOnnxRuntime();

      // Load model
      await _loadModel();

      // Warm up model
      await _warmUpModel();

      _isInitialized = true;
      _logger.i('✅ ONNX Emotion Service Initialized Successfully.');
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to initialize ONNX emotion detection service',
          error: e, stackTrace: stackTrace);
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Load emotion classes from labels.txt
  Future<void> _loadEmotionClasses() async {
    try {
      final labelsData = await rootBundle.loadString(_labelsAssetPath);
      _emotionClasses = labelsData
          .trim()
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      _logger.i('Loaded emotion classes: $_emotionClasses');
      if (_emotionClasses.isEmpty) throw Exception('No classes loaded');
    } catch (e) {
      _logger.w('Failed to load labels from asset, using fallback', error: e);
      // Fallback to hardcoded classes for AFEW dataset
      _emotionClasses = [
        'Anger',
        'Contempt',
        'Disgust',
        'Fear',
        'Happy',
        'Neutral',
        'Sad',
        'Surprise'
      ];
    }
  }

  /// Initialize ONNX Runtime
  Future<void> _initializeOnnxRuntime() async {
    try {
      _env = OrtEnv.instance;
    } catch (e) {
      _logger.e('❌ Failed to initialize ONNX Runtime environment', error: e);
      rethrow;
    }
  }

  /// Load model from assets and create inference session
  Future<void> _loadModel() async {
    if (_env == null) throw Exception('ONNX Runtime not initialized');

    try {
      // Load model bytes from assets
      final modelBytes = await rootBundle.load(_modelAssetPath);
      final sessionOptions = OrtSessionOptions();
      
      // Use OrtSession.fromBuffer to create the session
      _session = OrtSession.fromBuffer(
        modelBytes.buffer
            .asUint8List(modelBytes.offsetInBytes, modelBytes.lengthInBytes),
        sessionOptions,
      );
      _logger.i('ONNX session created successfully.');
    } catch (e) {
      _logger.e('❌ Could not load ONNX model or create session', error: e);
      rethrow;
    }
  }

  /// Warm up model with dummy inferences
  Future<void> _warmUpModel() async {
    // Note: Warm-up is disabled until initialization is fully stable
    // to avoid masking initialization errors.
    // You can re-enable this after confirming the model works.
    _logger.i('Model warm-up skipped for now.');
  }

  /// Detect emotions from image bytes
  Future<EmotionResult> detectEmotions(Uint8List imageBytes) async {
    if (!_isInitialized || _session == null) {
      _logger.e('OnnxEmotionService not initialized. Call initialize() first.');
      throw Exception(
          'OnnxEmotionService not initialized. Call initialize() first.');
    }

    final stopwatch = Stopwatch()..stop();
    stopwatch.start();

    try {
      // Preprocess image
      final preprocessedInput = await _preprocessImage(imageBytes);

      // Run inference
      final probabilities = await _runInference(preprocessedInput);
      
      // Apply Softmax to get probabilities
      final probabilitiesSoftmax = _softmax(probabilities);

      // Process results
      final emotions = <String, double>{};
      for (int i = 0; i < _emotionClasses.length; i++) {
        emotions[_emotionClasses[i]] = probabilitiesSoftmax[i];
      }

      // Find dominant emotion
      final maxEntry =
          emotions.entries.reduce((a, b) => a.value > b.value ? a : b);

      // Update performance metrics
      _updatePerformanceMetrics(stopwatch.elapsedMilliseconds.toDouble());

      final result = EmotionResult(
        emotion: maxEntry.key,
        confidence: maxEntry.value,
        allEmotions: emotions,
        timestamp: DateTime.now(),
        processingTimeMs: stopwatch.elapsedMilliseconds,
      );
      
      _logger.i('Emotion detected: ${result.emotion} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      return result;
    } catch (e, stackTrace) {
      _logger.e('❌ Emotion detection failed', error: e, stackTrace: stackTrace);
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Detect emotions from image file
  Future<EmotionResult> detectEmotionsFromFile(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    return detectEmotions(imageBytes);
  }

  /// Preprocess image for model input (NCHW format)
  Future<Float32List> _preprocessImage(Uint8List imageBytes) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Resize to model input size
      final resized =
          img.copyResize(image, width: _inputWidth, height: _inputHeight);

      // Convert to NCHW Float32List and normalize
      final input = Float32List(1 * _inputChannels * _inputHeight * _inputWidth);

      int index = 0;
      // Format: NCHW (batch, channels, height, width)
      for (int c = 0; c < _inputChannels; c++) {
        for (int y = 0; y < _inputHeight; y++) {
          for (int x = 0; x < _inputWidth; x++) {
            final pixel = resized.getPixel(x, y);

            double value;
            if (c == 0)
              value = pixel.r / 255.0; // Red
            else if (c == 1)
              value = pixel.g / 255.0; // Green
            else
              value = pixel.b / 255.0; // Blue

            // Apply ImageNet normalization
            input[index++] = ((value - _meanImageNet[c]) / _stdImageNet[c]);
          }
        }
      }

      return input;
    } catch (e) {
      _logger.e('❌ Image preprocessing failed', error: e);
      rethrow;
    }
  }

  /// Run ONNX model inference
  Future<List<double>> _runInference(Float32List input) async {
    if (_session == null) throw Exception('ONNX session not initialized');

    OrtValue? inputOrt;
    OrtRunOptions? runOptions;
    List<OrtValue?>? outputs;

    try {
      // Create the input tensor
      // THIS IS THE FIX: Use OrtValueTensor.createTensorWithDataList
      inputOrt = OrtValueTensor.createTensorWithDataList(input, _inputShape);

      // Get input and output names from the model
      final inputNames = _session!.inputNames;
      final outputNames = _session!.outputNames;
      
      if (inputNames.isEmpty) throw Exception("Model has no inputs");
      if (outputNames.isEmpty) throw Exception("Model has no outputs");

      final inputs = {inputNames.first: inputOrt};

      // Create run options
      runOptions = OrtRunOptions();

      // Run the model asynchronously
      // THIS IS THE SECOND FIX: Use runAsync
      outputs = await _session!.runAsync(runOptions, inputs);

      if (outputs == null || outputs.isEmpty || outputs.first == null) {
        throw Exception('Model execution returned no outputs');
      }

      // Get the output data
      final outputValue = outputs.first!.value;

      // Ensure the output is in the expected format [1, 8]
      if (outputValue is List<List<dynamic>>) {
        final outputData = outputValue;
        
        if (outputData.isEmpty || outputData.first.isEmpty) {
          throw Exception('Model output list is empty');
        }

        // Flatten and convert to List<double>
        final probabilities = outputData.first.map((e) => e as double).toList();

        if (probabilities.length != _emotionClasses.length) {
          _logger.e('Output mismatch: Model output ${probabilities.length} classes, but labels file has ${_emotionClasses.length}');
          throw Exception('Model output size mismatch');
        }
        return probabilities;
      } else {
        _logger.e('Unexpected output type: ${outputValue.runtimeType}');
        _logger.e('Output value: $outputValue');
        throw Exception('Unexpected model output type');
      }
    } catch (e) {
      _logger.e('❌ ONNX inference failed', error: e);
      rethrow;
    } finally {
      // IMPORTANT: Release resources to avoid memory leaks
      inputOrt?.release();
      runOptions?.release();
      outputs?.forEach((o) => o?.release());
    }
  }

  /// Apply softmax to the model output logits
  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];

    final double maxLogit = logits.reduce(max);
    final List<double> expValues =
        logits.map((logit) => exp(logit - maxLogit)).toList();

    final double sumExp = expValues.reduce((a, b) => a + b);

    if (sumExp == 0) {
      return List<double>.filled(logits.length, 1.0 / logits.length);
    }
    
    return expValues.map((val) => val / sumExp).toList();
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(double inferenceTime) {
    _inferenceTimes.add(inferenceTime);
    _totalInferences++;
    if (_inferenceTimes.length > 100) {
      _inferenceTimes.removeAt(0);
    }
  }

  /// Get performance statistics
  PerformanceStats getPerformanceStats() {
    if (_inferenceTimes.isEmpty) return PerformanceStats.empty();
    final avgTime =
        _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length;
    return PerformanceStats(
      averageInferenceTimeMs: avgTime,
      maxInferenceTimeMs: _inferenceTimes.reduce(max),
      minInferenceTimeMs: _inferenceTimes.reduce(min),
      totalInferences: _totalInferences,
    );
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _session != null;

  /// Get emotion classes
  List<String> get emotionClasses => List.unmodifiable(_emotionClasses);

  /// Dispose resources
  Future<void> dispose() async {
    _logger.i('Disposing ONNX service...');
    try {
      _session?.release();
      // Note: OrtEnv is a singleton and releasing it might affect other services
      // _env?.release();
      _session = null;
      _isInitialized = false;
      _inferenceTimes.clear();
      _logger.i('🗑️ ONNX emotion detection service disposed');
    } catch (e) {
      _logger.e('❌ Error during disposal', error: e);
    }
  }
}

/// Performance statistics
class PerformanceStats {
  final double averageInferenceTimeMs;
  final double maxInferenceTimeMs;
  final double minInferenceTimeMs;
  final int totalInferences;

  const PerformanceStats({
    required this.averageInferenceTimeMs,
    required this.maxInferenceTimeMs,
    required this.minInferenceTimeMs,
    required this.totalInferences,
  });

  factory PerformanceStats.empty() {
    return const PerformanceStats(
      averageInferenceTimeMs: 0,
      maxInferenceTimeMs: 0,
      minInferenceTimeMs: 0,
      totalInferences: 0,
    );
  }

  @override
  String toString() {
    return 'PerformanceStats(avg: ${averageInferenceTimeMs.toStringAsFixed(1)}ms, '
        'total: $totalInferences)';
  }
}

// Ensure the EmotionResult class is imported or defined
// I'm assuming it's in the import:
// import '../../../data/models/emotion_result.dart';