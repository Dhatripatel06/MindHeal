import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

// Conditional import f    print('📊 Raw emotion probabilities: $emotions');r TFLite - only on mobile platforms
import 'package:tflite_flutter/tflite_flutter.dart'
    if (dart.library.html) 'tflite_stub.dart';

class EmotionRecognitionService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  static const String MODEL_PATH = 'assets/models/emotion_model.tflite';
  static const String LABELS_PATH = 'assets/models/emotion_labels.txt';
  static const int INPUT_SIZE = 224;
  static const int NUM_CLASSES = 7;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      print('🔧 Loading TFLite model from: $MODEL_PATH');

      // Check if model file exists
      final modelData = await rootBundle.load(MODEL_PATH);
      print('📁 Model file loaded, size: ${modelData.lengthInBytes} bytes');

      // Load model
      final modelBuffer = modelData.buffer.asUint8List();
      print('🔄 Creating interpreter...');
      print('📊 Model buffer size: ${modelBuffer.length} bytes');

      // Create interpreter with basic options - avoid delegates that might cause issues
      final interpreterOptions = InterpreterOptions()
        ..threads = 1; // Use single thread to avoid memory issues

      // Don't use GPU or NNAPI delegates for now to avoid compatibility issues
      print('⚠️ Using CPU-only inference (no delegates)');

      try {
        _interpreter =
            Interpreter.fromBuffer(modelBuffer, options: interpreterOptions);
        print('✅ Interpreter created successfully');
      } catch (e) {
        print('❌ Failed to create interpreter: $e');
        // Try without options as fallback
        print('🔄 Trying fallback interpreter creation...');
        _interpreter = Interpreter.fromBuffer(modelBuffer);
        print('✅ Interpreter created with fallback options');
      }

      // Get input/output details
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();

      print('📊 Model input tensors: ${inputTensors.length}');
      for (var tensor in inputTensors) {
        print(
            '  Input: ${tensor.name}, shape: ${tensor.shape}, type: ${tensor.type}');
      }

      print('📊 Model output tensors: ${outputTensors.length}');
      for (var tensor in outputTensors) {
        print(
            '  Output: ${tensor.name}, shape: ${tensor.shape}, type: ${tensor.type}');
      }

      // Load labels
      print('🏷️ Loading emotion labels...');
      final labelsData = await rootBundle.loadString(LABELS_PATH);
      _labels = labelsData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      print('📋 Loaded ${_labels.length} emotion labels: $_labels');

      if (_labels.length != NUM_CLASSES) {
        throw Exception(
            'Labels file should contain exactly $NUM_CLASSES labels, found ${_labels.length}');
      }

      print('✅ Model loaded successfully. Labels: $_labels');
      _isInitialized = true;
      return true;
    } catch (e, stackTrace) {
      print('❌ Failed to initialize model: $e');
      print('❌ Stack trace: $stackTrace');
      _isInitialized = false;
      return false;
    }
  }

  Future<Map<String, dynamic>> analyzeImage(File imageFile) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('Model not initialized');
    }

    try {
      print('🖼️ Preprocessing image...');

      // Preprocess image with memory management
      final inputBuffer = await _preprocessImage(imageFile);

      print('📊 Input buffer size: ${inputBuffer.length} bytes');
      print('📊 Expected input size: ${1 * INPUT_SIZE * INPUT_SIZE * 3}');

      // Check interpreter
      if (_interpreter == null) {
        throw StateError('Interpreter is null');
      }

      print('🤖 Running inference...');

      // Prepare output buffer
      final outputShape = _interpreter!.getOutputTensors()[0].shape;
      final outputSize = outputShape.reduce((a, b) => a * b);
      final outputBuffer = Uint8List(outputSize);

      print(
          '📤 Running inference with input shape: [1, $INPUT_SIZE, $INPUT_SIZE, 3], output shape: $outputShape');

      // Run inference
      _interpreter!.run(inputBuffer, outputBuffer);

      print('🤖 Inference completed successfully');

      print('📊 Processing results...');

      // Process output
      final rawEmotions = await _postprocessOutput(outputBuffer);

      // Find exact dominant emotion from raw model output
      final dominantEntry =
          rawEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);
      final exactEmotion = dominantEntry.key;
      final exactProbability = dominantEntry.value;

      print('🎯 EXACT MODEL RESULTS:');
      print('   Dominant Emotion: $exactEmotion');
      print('   Raw Probability: ${(exactProbability * 100).toStringAsFixed(2)}%');
      print('   All Raw Probabilities: ${rawEmotions.map((k, v) => MapEntry(k, '${(v * 100).toStringAsFixed(2)}%')).toString()}');

      // Return REAL TFLITE MODEL RESULTS (no boosting)
      print('✅ REAL TFLITE RESULT: $exactEmotion (${(exactProbability * 100).toStringAsFixed(2)}% raw model probability)');
      print('📊 Raw emotion breakdown: ${rawEmotions.map((k, v) => MapEntry(k, '${(v * 100).toStringAsFixed(2)}%')).toString()}');

      return {
        'primaryEmotion': exactEmotion,
        'confidence': exactProbability,  // REAL model confidence, not boosted
        'rawProbability': exactProbability,
        'rawEmotions': rawEmotions,
        'emotionConfidences': rawEmotions,  // Return raw emotions, not boosted
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error in image analysis: $e');
      rethrow;
    }
  }

  Future<Uint8List> _preprocessImage(File imageFile) async {
    // Read image bytes
    final bytes = await imageFile.readAsBytes();

    // Decode image with memory optimization
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize to 224x224 with memory cleanup
    final resizedImage =
        img.copyResize(image, width: INPUT_SIZE, height: INPUT_SIZE);

    // Create input buffer [1, 224, 224, 3] - optimized size
    final inputBuffer = Uint8List(1 * INPUT_SIZE * INPUT_SIZE * 3);

    // Get image bytes directly from resized image
    final imageBytes = resizedImage.getBytes();

    // Process pixels more efficiently - batch processing
    const int batchSize = 1024; // Process pixels in batches
    for (int batchStart = 0;
        batchStart < INPUT_SIZE * INPUT_SIZE;
        batchStart += batchSize) {
      final batchEnd =
          math.min(batchStart + batchSize, INPUT_SIZE * INPUT_SIZE);

      for (int i = batchStart; i < batchEnd; i++) {
        final pixelIndex = i * resizedImage.numChannels;

        // Extract RGB values and convert to 0-255 range
        final r = imageBytes[pixelIndex].toDouble();
        final g = imageBytes[pixelIndex + 1].toDouble();
        final b = imageBytes[pixelIndex + 2].toDouble();

        // No normalization - just clamp to 0-255
        final uint8R = r.round().clamp(0, 255);
        final uint8G = g.round().clamp(0, 255);
        final uint8B = b.round().clamp(0, 255);

        // Set in buffer (NHWC format: batch, height, width, channels)
        final bufferIndex = i * 3;
        inputBuffer[bufferIndex] = uint8R;
        inputBuffer[bufferIndex + 1] = uint8G;
        inputBuffer[bufferIndex + 2] = uint8B;
      }

      // Allow garbage collection between batches
      await Future.delayed(Duration.zero);
    }

    return inputBuffer;
  }

  Future<Map<String, double>> _postprocessOutput(Uint8List outputBuffer) async {
    final emotions = <String, double>{};

    print('🔢 Raw model output values: ${outputBuffer.take(7).toList()}');

    // Model outputs logits as uint8, apply softmax to get probabilities
    final logits = List<double>.generate(NUM_CLASSES, (i) => outputBuffer[i].toDouble());
    
    // Apply softmax: exp(logit - max_logit) / sum(exp(logit - max_logit))
    final maxLogit = logits.reduce(math.max);
    final expValues = logits.map((logit) => math.exp(logit - maxLogit)).toList();
    final sum = expValues.reduce((a, b) => a + b);
    
    for (int i = 0; i < NUM_CLASSES; i++) {
      final probability = expValues[i] / sum;
      final emotion = _labels[i];
      emotions[emotion] = probability;

      print('🎯 $emotion: ${(probability * 100).toStringAsFixed(2)}%');
    }

    print('� Raw emotion probabilities: $emotions');

    // Find the highest probability
    final maxProb = emotions.values.reduce(math.max);
    final dominantEmotion =
        emotions.entries.firstWhere((e) => e.value == maxProb).key;

    print(
        '🏆 EXACT DETECTED EMOTION: $dominantEmotion (${(maxProb * 100).toStringAsFixed(2)}% raw probability)');

    return emotions;
  }

  Future<Map<String, double>> analyzeImageFromBytes(Uint8List bytes) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('Model not initialized');
    }

    try {
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_image.jpg');
      await tempFile.writeAsBytes(bytes);

      final result = await analyzeImage(tempFile);

      // Clean up
      await tempFile.delete();

      return Map<String, double>.from(result['emotionConfidences']);
    } catch (e) {
      print('❌ Error analyzing image from bytes: $e');
      rethrow;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    print('🗑️ TFLite interpreter disposed');
  }

  bool get isInitialized => _isInitialized;
}

// Singleton instance for backward compatibility
class tfliteService {
  static final EmotionRecognitionService _instance =
      EmotionRecognitionService();

  // Static methods (used by the provider)
  static Future<bool> initialize() => _instance.initialize();
  static Future<Map<String, dynamic>> analyzeImage(File imageFile) =>
      _instance.analyzeImage(imageFile);
  static Future<Map<String, double>> analyzeImageFromBytes(Uint8List bytes) =>
      _instance.analyzeImageFromBytes(bytes);
  static void dispose() => _instance.dispose();
  static bool get isInitialized => _instance.isInitialized;
}
