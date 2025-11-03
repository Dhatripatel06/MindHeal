// File: lib/features/mood_detection/onnx_emotion_detection/data/services/onnx_emotion_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/foundation.dart'; // Import for compute
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
// Import the onnxruntime package
import 'package:onnxruntime/onnxruntime.dart';

// Assuming EmotionResult is in this path based on previous context
import '../../../data/models/emotion_result.dart';

// --- NEW --- TOP-LEVEL FUNCTION FOR COMPUTE ---
// This function will run in a separate isolate.
// It must be a top-level function or a static method.
Future<EmotionResult> _detectEmotionsInIsolate(Uint8List imageBytes) async {
  // Get the service instance. This will create a new instance
  // for this isolate, with its own static variables.
  final service = OnnxEmotionService.instance;

  // Ensure the service (and its static session) is initialized *in this isolate*.
  // This is crucial. It will load the model into memory for this isolate.
  await service.initialize();

  final stopwatch = Stopwatch()..start();
  try {
    // Now, call the static processing methods
    final preprocessedInput =
        await OnnxEmotionService._preprocessImage(imageBytes);
    final probabilities = await OnnxEmotionService._runInference(preprocessedInput);
    final probabilitiesSoftmax = OnnxEmotionService._softmax(probabilities);

    final emotions = <String, double>{};
    for (int i = 0; i < OnnxEmotionService._emotionClasses.length; i++) {
      emotions[OnnxEmotionService._emotionClasses[i]] = probabilitiesSoftmax[i];
    }

    final maxEntry = emotions.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Use the static scaling method
    final scaledConfidence = OnnxEmotionService._scaleConfidence(maxEntry.value);

    stopwatch.stop();
    final result = EmotionResult(
      emotion: maxEntry.key,
      confidence: scaledConfidence,
      allEmotions: emotions,
      timestamp: DateTime.now(),
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );

    // Note: Logging from an isolate might not appear in the main console
    // service._logger.i('ISOLATE Emotion detected: ${result.emotion}');
    return result;
  } catch (e, stackTrace) {
    stopwatch.stop();
    // service._logger.e('❌ ISOLATE Emotion detection failed', error: e, stackTrace: stackTrace);
    // This factory correctly uses 'errorMessage' as a parameter and assigns it to 'error'
    return EmotionResult.error('Isolate detection failed: $e');
  }
}
// --- END NEW ---

class OnnxEmotionService {
  static const String _modelAssetPath =
      'assets/models/enet_b0_8_best_afew.onnx'; //
  static const String _labelsAssetPath = 'assets/models/labels.txt'; //
  // Model specifications
  static const int _inputWidth = 224; //
  static const int _inputHeight = 224; //
  static const int _inputChannels = 3; //
  // The model's input shape [batch_size, channels, height, width]
  static final _inputShape = [1, _inputChannels, _inputHeight, _inputWidth]; //

  // ImageNet normalization parameters (used in EfficientNet-B0)
  static const List<double> _meanImageNet = [0.485, 0.456, 0.406]; //
  static const List<double> _stdImageNet = [0.229, 0.224, 0.225]; //

  final Logger _logger = Logger(); //

  // Core ONNX Runtime components
  static OrtEnv? _env; //
  static OrtSession? _session; //

  // --- MODIFIED --- Made static
  static List<String> _emotionClasses = []; //
  bool _isInitialized = false; //
  bool _isInitializing = false; //

  // Performance tracking
  final List<double> _inferenceTimes = []; //
  int _totalInferences = 0; //

  // Singleton pattern
  static OnnxEmotionService? _instance; //
  static OnnxEmotionService get instance {
    _instance ??= OnnxEmotionService._internal(); //
    return _instance!;
  }

  OnnxEmotionService._internal(); //

  /// Initialize the emotion detection service
  Future<bool> initialize() async {
    // --- MODIFIED --- Allow re-initialization in different isolates
    // Only block if this *specific instance* is initializing.
    if (_isInitialized) return true;
    if (_isInitializing) {
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _isInitialized;
    }
    // --- END MODIFIED ---

    _isInitializing = true; //
    _logger.i('Initializing ONNX Emotion Service...'); //

    try {
      // Load emotion classes from labels.txt
      await _loadEmotionClasses(); //

      // Initialize ONNX Runtime
      await _initializeOnnxRuntime(); //

      // Load model
      await _loadModel(); //

      _isInitialized = true; //
      _logger.i('✅ ONNX Emotion Service Initialized Successfully.'); //
      return true;
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to initialize ONNX emotion detection service', //
          error: e, stackTrace: stackTrace); //
      _isInitialized = false; //
      return false;
    } finally {
      _isInitializing = false; //
    }
  }

  /// Load emotion classes from labels.txt
  Future<void> _loadEmotionClasses() async {
    // --- MODIFIED --- Check if static list is already populated
    if (_emotionClasses.isNotEmpty) return;
    // --- END MODIFIED ---

    try {
      final labelsData = await rootBundle.loadString(_labelsAssetPath); //
      _emotionClasses = labelsData //
          .trim()
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(); //
      _logger.i('Loaded emotion classes: $_emotionClasses'); //
      if (_emotionClasses.isEmpty) throw Exception('No classes loaded'); //
    } catch (e) {
      _logger.w('Failed to load labels from asset, using fallback', error: e); //
      // Fallback to hardcoded classes for AFEW dataset
      _emotionClasses = [ //
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
    // --- MODIFIED --- Check if static env is already populated
    if (_env != null) return;
    // --- END MODIFIED ---
    try {
      _env = OrtEnv.instance; //
    } catch (e) {
      _logger.e('❌ Failed to initialize ONNX Runtime environment', error: e); //
      rethrow;
    }
  }

  /// Load model from assets and create inference session
  Future<void> _loadModel() async {
    // --- MODIFIED --- Check if static session is already populated
    if (_session != null) return;
    // --- END MODIFIED ---
    if (_env == null) throw Exception('ONNX Runtime not initialized'); //

    try {
      // Load model bytes from assets
      final modelBytes = await rootBundle.load(_modelAssetPath); //
      final sessionOptions = OrtSessionOptions(); //

      // Use OrtSession.fromBuffer to create the session
      _session = OrtSession.fromBuffer( //
        modelBytes.buffer
            .asUint8List(modelBytes.offsetInBytes, modelBytes.lengthInBytes),
        sessionOptions,
      );
      _logger.i('ONNX session created successfully.'); //
    } catch (e) {
      _logger.e('❌ Could not load ONNX model or create session', error: e); //
      rethrow;
    }
  }

  // --- MODIFIED --- Made static
  /// Scales the confidence score to the desired range (e.g., 90-99%).
  /// Warning: This artificially inflates the displayed confidence.
  static double _scaleConfidence(double originalConfidence) {
    // Map the input range [0.0, 1.0] to the output range [0.9, 0.09]
    // scaled = min_output + (original * (max_output - min_output))
    return 0.9 + (originalConfidence * 0.09);
  }
  // --- END MODIFIED ---

  /// Detect emotions from image bytes
  Future<EmotionResult> detectEmotions(Uint8List imageBytes) async {
    if (!_isInitialized || _session == null) {
      _logger.e('OnnxEmotionService not initialized. Call initialize() first.');
      throw Exception(
          'OnnxEmotionService not initialized. Call initialize() first.');
    }

    // --- MODIFIED ---
    // Delegate the heavy work to the isolate function using compute
    final stopwatch = Stopwatch()..start();

    try {
      // compute runs _detectEmotionsInIsolate in a background isolate
      // and passes imageBytes to it.
      final EmotionResult result =
          await compute(_detectEmotionsInIsolate, imageBytes);

      stopwatch.stop();

      if (result.hasError) {
        // --- THIS IS THE FIX ---
        // Changed `result.errorMessage` to `result.error`
        _logger.e('❌ Emotion detection failed in isolate',
            error: result.error); 
        // --- END FIX ---
        return result;
      }

      // Log performance from the main thread's perspective (includes isolate spawn time)
      final totalTime = stopwatch.elapsedMilliseconds.toDouble();
      _updatePerformanceMetrics(totalTime);
      _logger.i(
          'Emotion detected: ${result.emotion} (Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%) - Total time: ${totalTime.toStringAsFixed(0)}ms (Processing: ${result.processingTimeMs}ms)');

      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.e('❌ Failed to run compute task', error: e, stackTrace: stackTrace);
      return EmotionResult.error('Compute task failed: $e');
    }
    // --- END MODIFIED ---
  }

  /// Real-time detection with frame stabilization
  Future<EmotionResult> detectEmotionsRealTime( //
    Uint8List imageBytes, {
    EmotionResult? previousResult,
    double stabilizationFactor = 0.3,
  }) async {
    // Get the current, real detection result (which already includes scaled confidence)
    // This call is now non-blocking and runs in an isolate.
    final currentResult = await detectEmotions(imageBytes); //

    // If current detection failed, return the error
    if (currentResult.hasError) { //
      return currentResult;
    }

    // Apply stabilization if previous result is valid
    // This part is light and can run on the main thread
    if (previousResult != null &&
        stabilizationFactor > 0 &&
        !previousResult.hasError) {
      // Apply temporal stabilization to reduce flickering using the original probabilities
      final stabilizedEmotions = <String, double>{}; //

      // --- MODIFIED --- Use static _emotionClasses
      for (final emotion in _emotionClasses) {
        // Use the original (unscaled) probabilities from allEmotions map
        final currentValue = currentResult.allEmotions[emotion] ?? 0.0; //
        final previousValue = previousResult.allEmotions[emotion] ?? 0.0; //

        // Weighted average for stabilization
        final stabilizedValue = currentValue * (1 - stabilizationFactor) + //
            previousValue * stabilizationFactor;
        stabilizedEmotions[emotion] = stabilizedValue; //
      }

      // Find new dominant emotion from stabilized values
      final maxEntry = stabilizedEmotions.entries //
          .reduce((a, b) => a.value > b.value ? a : b);

      // --- MODIFIED ---
      // Scale the stabilized confidence for display
      // Use static _scaleConfidence method
      final scaledStabilizedConfidence = _scaleConfidence(maxEntry.value);
      // --- END MODIFIED ---

      return EmotionResult( //
        emotion: maxEntry.key,
        confidence: scaledStabilizedConfidence, // Use scaled stabilized confidence
        allEmotions: stabilizedEmotions, // Keep stabilized probabilities here
        timestamp: DateTime.now(),
        processingTimeMs: currentResult
            .processingTimeMs, // Use processing time from original detection
      );
    }

    // Return the raw result (already has scaled confidence from detectEmotions call)
    // if no stabilization is needed or possible
    return currentResult; //
  }

  /// Detect emotions from image file
  Future<EmotionResult> detectEmotionsFromFile(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes(); //
    return detectEmotions(imageBytes); //
  }

  /// Batch processing for multiple images
  Future<List<EmotionResult>> detectEmotionsBatch( //
      List<Uint8List> imageBytesList) async {
    if (!_isInitialized) { //
      throw Exception('OnnxEmotionService not initialized');
    }
    final results = <EmotionResult>[]; //
    final stopwatch = Stopwatch()..start(); //
    _logger
        .d('🎯 Starting batch detection for ${imageBytesList.length} images...'); //
    for (int i = 0; i < imageBytesList.length; i++) { //
      // detectEmotions already handles scaling and runs in an isolate
      final result = await detectEmotions(imageBytesList[i]); //
      results.add(result); //
    }
    _logger
        .d('🎉 Batch processing completed in ${stopwatch.elapsedMilliseconds}ms'); //
    return results;
  }

  // --- MODIFIED --- Made static
  /// Preprocess image for model input (NCHW format)
  static Future<Float32List> _preprocessImage(Uint8List imageBytes) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes); //
      if (image == null) throw Exception('Failed to decode image'); //

      // Resize to model input size
      final resized = //
          img.copyResize(image, width: _inputWidth, height: _inputHeight);

      // Convert to NCHW Float32List and normalize
      final input = Float32List(1 * _inputChannels * _inputHeight * _inputWidth); //

      int index = 0; //
      // Format: NCHW (batch, channels, height, width)
      for (int c = 0; c < _inputChannels; c++) { //
        for (int y = 0; y < _inputHeight; y++) { //
          for (int x = 0; x < _inputWidth; x++) { //
            final pixel = resized.getPixel(x, y); //

            double value; //
            if (c == 0) //
              value = pixel.r / 255.0; // Red //
            else if (c == 1) //
              value = pixel.g / 255.0; // Green //
            else //
              value = pixel.b / 255.0; // Blue //

            // Apply ImageNet normalization
            input[index++] = ((value - _meanImageNet[c]) / _stdImageNet[c]); //
          }
        }
      }

      return input; //
    } catch (e) {
      // Cannot use instance logger in static method
      // _logger.e('❌ Image preprocessing failed', error: e); //
      print('❌ Image preprocessing failed: $e');
      rethrow;
    }
  }
  // --- END MODIFIED ---

  // --- MODIFIED --- Made static
  /// Run ONNX model inference
  static Future<List<double>> _runInference(Float32List input) async {
    if (_session == null) throw Exception('ONNX session not initialized'); //

    OrtValue? inputOrt; //
    OrtRunOptions? runOptions; //
    List<OrtValue?>? outputs; //

    try {
      // Create the input tensor
      inputOrt = OrtValueTensor.createTensorWithDataList(input, _inputShape); //

      // Get input and output names from the model
      final inputNames = _session!.inputNames; //
      final outputNames = _session!.outputNames; //

      if (inputNames.isEmpty) throw Exception("Model has no inputs"); //
      if (outputNames.isEmpty) throw Exception("Model has no outputs"); //

      final inputs = {inputNames.first: inputOrt}; //

      // Create run options
      runOptions = OrtRunOptions(); //

      // Run the model asynchronously
      outputs = await _session!.runAsync(runOptions, inputs); //

      if (outputs == null || outputs.isEmpty || outputs.first == null) { //
        throw Exception('Model execution returned no outputs');
      }

      // Get the output data
      final outputValue = outputs.first!.value; //

      // Ensure the output is in the expected format [1, 8]
      if (outputValue is List<List<dynamic>>) { //
        final outputData = outputValue; //

        if (outputData.isEmpty || outputData.first.isEmpty) { //
          throw Exception('Model output list is empty');
        }

        // Flatten and convert to List<double>
        final probabilities = outputData.first.map((e) => e as double).toList(); //

        if (probabilities.length != _emotionClasses.length) { //
          // Cannot use instance logger in static method
          print(
              'Output mismatch: Model output ${probabilities.length} classes, but labels file has ${_emotionClasses.length}');
          throw Exception('Model output size mismatch');
        }
        return probabilities; //
      } else {
        // Cannot use instance logger in static method
        print('Unexpected output type: ${outputValue.runtimeType}'); //
        print('Output value: $outputValue'); //
        throw Exception('Unexpected model output type');
      }
    } catch (e) {
      // Cannot use instance logger in static method
      print('❌ ONNX inference failed: $e'); //
      rethrow;
    } finally {
      // IMPORTANT: Release resources to avoid memory leaks
      inputOrt?.release(); //
      runOptions?.release(); //
      outputs?.forEach((o) => o?.release()); //
    }
  }
  // --- END MODIFIED ---

  // --- MODIFIED --- Made static
  /// Apply softmax to the model output logits
  static List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return []; //

    final double maxLogit = logits.reduce(max); //
    final List<double> expValues = //
        logits.map((logit) => exp(logit - maxLogit)).toList();

    final double sumExp = expValues.reduce((a, b) => a + b); //

    if (sumExp == 0) { //
      // Avoid division by zero, return uniform distribution
      return List<double>.filled(logits.length, 1.0 / logits.length);
    }

    return expValues.map((val) => val / sumExp).toList(); //
  }
  // --- END MODIFIED ---

  /// Update performance metrics
  void _updatePerformanceMetrics(double inferenceTime) {
    _inferenceTimes.add(inferenceTime); //
    _totalInferences++; //
    if (_inferenceTimes.length > 100) { //
      _inferenceTimes.removeAt(0); //
    }
  }

  /// Get performance statistics
  PerformanceStats getPerformanceStats() {
    if (_inferenceTimes.isEmpty) return PerformanceStats.empty(); //
    final avgTime = //
        _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length;
    return PerformanceStats( //
      averageInferenceTimeMs: avgTime,
      maxInferenceTimeMs: _inferenceTimes.reduce(max),
      minInferenceTimeMs: _inferenceTimes.reduce(min),
      totalInferences: _totalInferences,
    );
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _session != null; //

  /// Get emotion classes
  List<String> get emotionClasses => List.unmodifiable(_emotionClasses); //

  /// Dispose resources
  Future<void> dispose() async {
    _logger.i('Disposing ONNX service...'); //
    try {
      _session?.release(); //
      _session = null; //
      // --- MODIFIED --- Also release the env
      _env?.release();
      _env = null;
      // --- END MODIFIED ---
      _isInitialized = false; //
      _inferenceTimes.clear(); //
      _logger.i('🗑️ ONNX emotion detection service disposed'); //
    } catch (e) {
      _logger.e('❌ Error during disposal', error: e); //
    }
  }
}

/// Performance statistics
class PerformanceStats {
  final double averageInferenceTimeMs; //
  final double maxInferenceTimeMs; //
  final double minInferenceTimeMs; //
  final int totalInferences; //

  const PerformanceStats({ //
    required this.averageInferenceTimeMs,
    required this.maxInferenceTimeMs,
    required this.minInferenceTimeMs,
    required this.totalInferences,
  });

  factory PerformanceStats.empty() { //
    return const PerformanceStats( //
      averageInferenceTimeMs: 0,
      maxInferenceTimeMs: 0,
      minInferenceTimeMs: 0,
      totalInferences: 0,
    );
  }

  @override
  String toString() { //
    return 'PerformanceStats(avg: ${averageInferenceTimeMs.toStringAsFixed(1)}ms, ' //
        'total: $totalInferences)';
  }
}