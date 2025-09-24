// Improved TFLite Service for MindHeal - Better Input Processing
// File: lib/features/mood_detection/data/services/tflite_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

// Emotion Recognition Result Models
class EmotionResult {
  final String emotion;
  final double confidence;
  final String confidenceLevel;
  final Map<String, double> allEmotions;
  final List<EmotionPrediction> topPredictions;
  final bool hasError;
  final String? errorMessage;
  final DateTime timestamp;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.confidenceLevel,
    required this.allEmotions,
    required this.topPredictions,
    this.hasError = false,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  EmotionResult.error(String error)
      : emotion = 'unknown',
        confidence = 0.0,
        confidenceLevel = 'low',
        allEmotions = {},
        topPredictions = [],
        hasError = true,
        errorMessage = error,
        timestamp = DateTime.now();

  // Mental health insights based on emotion
  String get mentalHealthInsight {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return confidence > 0.8
            ? "You're showing great positive energy! Keep nurturing this joy."
            : "There are signs of happiness. Focus on what brings you joy.";
      case 'neutral':
        return "You appear calm and balanced. This is a good state for reflection.";
      case 'sadness':
        return confidence > 0.7
            ? "It's okay to feel sad sometimes. Consider talking to someone you trust."
            : "You might be feeling a bit down. Self-care activities could help.";
      case 'anger':
        return "Strong emotions detected. Take a deep breath and try some relaxation techniques.";
      case 'fear':
        return "Feeling anxious? Try grounding exercises or reach out for support.";
      case 'disgust':
        return "You seem bothered by something. Identifying the cause might help.";
      case 'surprise':
        return "Something unexpected? Take a moment to process your feelings.";
      default:
        return "Remember, all emotions are valid. Take care of your mental well-being.";
    }
  }

  // Suggested activities based on emotion
  List<String> get suggestedActivities {
    switch (emotion.toLowerCase()) {
      case 'happiness':
        return [
          "Journal about what made you happy",
          "Share your joy with loved ones",
          "Engage in creative activities",
          "Practice gratitude meditation"
        ];
      case 'sadness':
        return [
          "Listen to calming music",
          "Practice gentle yoga",
          "Connect with a friend",
          "Try breathing exercises",
          "Consider professional support"
        ];
      case 'anger':
        return [
          "Try progressive muscle relaxation",
          "Go for a walk or exercise",
          "Practice deep breathing",
          "Write in a journal",
          "Listen to soothing sounds"
        ];
      case 'fear':
        return [
          "Practice grounding techniques",
          "Try mindfulness meditation",
          "Listen to guided relaxation",
          "Reach out to support network",
          "Use anxiety management tools"
        ];
      case 'neutral':
        return [
          "Explore mindfulness activities",
          "Try mood-boosting exercises",
          "Practice self-reflection",
          "Set positive intentions"
        ];
      default:
        return [
          "Practice self-care",
          "Try meditation",
          "Connect with others",
          "Engage in physical activity"
        ];
    }
  }
}

class EmotionPrediction {
  final String emotion;
  final double confidence;

  EmotionPrediction({required this.emotion, required this.confidence});
}

// Main Emotion Recognition Service
class EmotionRecognitionService {
  static const List<String> _emotionClasses = [
    'anger',
    'disgust', 
    'fear',
    'happiness',
    'neutral',
    'sadness',
    'surprise'
  ];

  static const int _inputSize = 224;
  
  Interpreter? _interpreter;
  late FaceDetector _faceDetector;
  bool _isInitialized = false;
  
  // Model input/output details
  TensorType? _inputType;
  TensorType? _outputType;
  List<int>? _inputShape;
  List<int>? _outputShape;

  // Confidence thresholds for mental health context
  static const double highConfidenceThreshold = 0.75;
  static const double mediumConfidenceThreshold = 0.55;

  // Singleton pattern
  static final EmotionRecognitionService _instance =
      EmotionRecognitionService._internal();
  factory EmotionRecognitionService() => _instance;
  EmotionRecognitionService._internal();

  bool get isInitialized => _isInitialized;
  List<String> get emotionClasses => _emotionClasses;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadModel();
      await _initializeFaceDetector();
      _isInitialized = true;
      print('✅ MindHeal Emotion Recognition Service initialized');
    } catch (e) {
      print('❌ Failed to initialize emotion recognition: $e');
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/models/emotion_model.tflite');

      // Get input and output tensor details
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      
      if (inputTensors.isNotEmpty) {
        _inputType = inputTensors[0].type;
        _inputShape = inputTensors[0].shape;
      }
      
      if (outputTensors.isNotEmpty) {
        _outputType = outputTensors[0].type;
        _outputShape = outputTensors[0].shape;
      }

      print('📊 Model loaded successfully');
      print('   Input shape: $_inputShape');
      print('   Input type: $_inputType');
      print('   Output shape: $_outputShape');
      print('   Output type: $_outputType');
      print('   Expected classes: ${_emotionClasses.length}');
    } catch (e) {
      print('❌ Error loading emotion model: $e');
      throw Exception('Failed to load emotion recognition model: $e');
    }
  }

  Future<void> _initializeFaceDetector() async {
    final options = FaceDetectorOptions(
      enableClassification: false,
      enableLandmarks: false,
      enableContours: false,
      enableTracking: false,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.fast,
    );

    _faceDetector = FaceDetector(options: options);
  }

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      final faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      print('Error detecting faces: $e');
      return [];
    }
  }

  Future<EmotionResult> analyzeEmotion(img.Image image, {Rect? faceRect}) async {
    if (!_isInitialized) {
      return EmotionResult.error('Service not initialized');
    }

    if (_interpreter == null) {
      return EmotionResult.error('Model not loaded');
    }

    try {
      print('🔍 Processing image for emotion analysis...');
      
      // Process image
      img.Image processedImage = image;

      if (faceRect != null) {
        print('✂️ Cropping face region');
        processedImage = _cropAndEnhanceFace(image, faceRect);
      } else {
        print('🖼️ Using full image');
        processedImage = _enhanceImageQuality(image);
      }

      print('⚙️ Preprocessing image...');
      
      // Try both input formats to see which works better
      final input = _inputType == TensorType.uint8 
          ? _preprocessImageAsUint8(processedImage)
          : _preprocessImageAsFloat32(processedImage);
      
      print('🤖 Running inference...');
      
      // Prepare output tensor based on output type
      final output = _outputType == TensorType.uint8 
          ? Uint8List(_emotionClasses.length)
          : Float32List(_emotionClasses.length);
      
      // Run inference with timeout
      final completer = Completer<void>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.completeError('Inference timeout');
        }
      });
      
      try {
        _interpreter!.run(input, output);
        if (!completer.isCompleted) {
          completer.complete();
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
      
      await completer.future;
      
      print('📊 Processing results...');
      
      // Convert output to probabilities
      List<double> probabilities;
      if (_outputType == TensorType.uint8) {
        // Dequantize and apply softmax
        final dequantized = (output as Uint8List).map((value) => 
            (value.toDouble() / 255.0)).toList();
        probabilities = _applySoftmax(dequantized);
      } else {
        // Apply softmax to float output
        probabilities = _applySoftmax((output as Float32List).toList());
      }
      
      // Debug: Print all probabilities
      for (int i = 0; i < probabilities.length && i < _emotionClasses.length; i++) {
        print('   ${_emotionClasses[i]}: ${(probabilities[i] * 100).toStringAsFixed(1)}%');
      }
      
      // Find best prediction with bounds checking
      if (probabilities.isEmpty) {
        return EmotionResult.error('Empty prediction results');
      }
      
      double maxValue = probabilities[0];
      int maxIndex = 0;
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxValue) {
          maxValue = probabilities[i];
          maxIndex = i;
        }
      }
      
      // Ensure maxIndex is within bounds
      if (maxIndex < 0 || maxIndex >= _emotionClasses.length) {
        return EmotionResult.error('Invalid prediction index: $maxIndex');
      }
      
      final confidence = maxValue;
      final emotion = _emotionClasses[maxIndex];

      print('✅ Analysis complete: $emotion (${(confidence * 100).toStringAsFixed(1)}%)');

      // Create top predictions with bounds checking
      final indexedPredictions = <MapEntry<int, double>>[];
      for (int i = 0; i < probabilities.length && i < _emotionClasses.length; i++) {
        indexedPredictions.add(MapEntry(i, probabilities[i]));
      }
      
      indexedPredictions.sort((a, b) => b.value.compareTo(a.value));
      final topPredictions = indexedPredictions
          .take(3)
          .map((entry) => EmotionPrediction(
                emotion: _emotionClasses[entry.key],
                confidence: entry.value,
              ))
          .toList();

      // Create emotion map with bounds checking
      final allEmotions = <String, double>{};
      for (int i = 0; i < probabilities.length && i < _emotionClasses.length; i++) {
        allEmotions[_emotionClasses[i]] = probabilities[i];
      }

      return EmotionResult(
        emotion: emotion,
        confidence: confidence,
        confidenceLevel: _getConfidenceLevel(confidence),
        allEmotions: allEmotions,
        topPredictions: topPredictions,
      );
    } catch (e) {
      print('❌ Error in emotion analysis: $e');
      return EmotionResult.error('Analysis failed: $e');
    }
  }

  img.Image _cropAndEnhanceFace(img.Image image, Rect faceRect, {double margin = 0.3}) {
    final imageWidth = image.width;
    final imageHeight = image.height;

    // Calculate crop coordinates with margin
    final centerX = faceRect.left + faceRect.width / 2;
    final centerY = faceRect.top + faceRect.height / 2;
    final size = math.max(faceRect.width, faceRect.height) * (1 + margin);

    final x = (centerX - size / 2).clamp(0, imageWidth - 1).round();
    final y = (centerY - size / 2).clamp(0, imageHeight - 1).round();
    final width = (size).clamp(1, imageWidth - x).round();
    final height = (size).clamp(1, imageHeight - y).round();

    // Crop and enhance
    final cropped = img.copyCrop(image, x, y, width, height);
    return _enhanceImageQuality(cropped);
  }

  img.Image _enhanceImageQuality(img.Image image) {
    // Light enhancement for better recognition
    var enhanced = image;
    
    try {
      // More aggressive enhancement for better emotion recognition
      enhanced = img.adjustColor(enhanced, 
          contrast: 1.1, 
          brightness: 1.05,
          gamma: 0.9);
      
      // Optional: Apply histogram equalization for better contrast
      enhanced = img.normalize(enhanced, 0, 255);
    } catch (e) {
      print('⚠️ Enhancement failed, using original: $e');
      enhanced = image;
    }
    
    return enhanced;
  }

  // Method 1: Uint8 preprocessing (current method)
  Uint8List _preprocessImageAsUint8(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    final input = Uint8List(_inputSize * _inputSize * 3);
    int pixelIndex = 0;
    
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        
        final red = img.getRed(pixel).clamp(0, 255);
        final green = img.getGreen(pixel).clamp(0, 255);
        final blue = img.getBlue(pixel).clamp(0, 255);
        
        if (pixelIndex < input.length - 2) {
          input[pixelIndex++] = red;
          input[pixelIndex++] = green;
          input[pixelIndex++] = blue;
        }
      }
    }
    
    return input;
  }

  // Method 2: Float32 preprocessing (alternative approach)
  Float32List _preprocessImageAsFloat32(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    final input = Float32List(_inputSize * _inputSize * 3);
    int pixelIndex = 0;
    
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        
        // Normalize to [-1, 1] or [0, 1] range
        final red = img.getRed(pixel) / 255.0;
        final green = img.getGreen(pixel) / 255.0;
        final blue = img.getBlue(pixel) / 255.0;
        
        if (pixelIndex < input.length - 2) {
          input[pixelIndex++] = red;
          input[pixelIndex++] = green;
          input[pixelIndex++] = blue;
        }
      }
    }
    
    return input;
  }

  // Method 3: Nested list preprocessing (from emotion_recognizer.dart)
  List<List<List<List<int>>>> _preprocessImageAsNestedList(img.Image image) {
    final resized = img.copyResize(image, width: _inputSize, height: _inputSize);
    
    return List.generate(
      1,
      (b) => List.generate(
        _inputSize,
        (y) => List.generate(
          _inputSize,
          (x) => List.generate(3, (c) {
            final pixel = resized.getPixel(x, y);
            if (c == 0) return img.getRed(pixel);
            if (c == 1) return img.getGreen(pixel);
            return img.getBlue(pixel);
          }),
        ),
      ),
    );
  }

  // Apply softmax to convert logits to probabilities
  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];
    
    // Find max value for numerical stability
    final maxLogit = logits.reduce(math.max);
    
    // Compute exponentials
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    
    // Compute sum of exponentials
    final sumExp = expValues.reduce((a, b) => a + b);
    
    // Avoid division by zero
    if (sumExp == 0) return List.filled(logits.length, 1.0 / logits.length);
    
    // Compute softmax probabilities
    return expValues.map((exp) => exp / sumExp).toList();
  }

  String _getConfidenceLevel(double confidence) {
    if (confidence >= highConfidenceThreshold) return 'high';
    if (confidence >= mediumConfidenceThreshold) return 'medium';
    return 'low';
  }

  // Camera image processing
  Future<EmotionResult> analyzeCameraImage(CameraImage cameraImage) async {
    try {
      final inputImage = _cameraImageToInputImage(cameraImage);
      final faces = await detectFaces(inputImage);
      final image = _cameraImageToImage(cameraImage);

      Rect? faceRect;
      if (faces.isNotEmpty) {
        final largestFace = faces.reduce((a, b) =>
            (a.boundingBox.width * a.boundingBox.height) >
                    (b.boundingBox.width * b.boundingBox.height)
                ? a
                : b);
        faceRect = largestFace.boundingBox;
      }

      return await analyzeEmotion(image, faceRect: faceRect);
    } catch (e) {
      print('Error analyzing camera image: $e');
      return EmotionResult.error('Camera analysis failed: $e');
    }
  }

  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    final metadata = InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: InputImageFormat.yuv420,
      bytesPerRow: cameraImage.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: cameraImage.planes[0].bytes,
      metadata: metadata,
    );
  }

  img.Image _cameraImageToImage(CameraImage cameraImage) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;

    final img.Image image = img.Image(width, height);

    // YUV to RGB conversion with bounds checking
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

        if (yIndex < yPlane.length && uvIndex < uPlane.length && uvIndex < vPlane.length) {
          final int yValue = yPlane[yIndex];
          final int uValue = uPlane[uvIndex] - 128;
          final int vValue = vPlane[uvIndex] - 128;

          int r = (yValue + 1.402 * vValue).round().clamp(0, 255);
          int g = (yValue - 0.344 * uValue - 0.714 * vValue).round().clamp(0, 255);
          int b = (yValue + 1.772 * uValue).round().clamp(0, 255);

          image.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }

    return image;
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
    _isInitialized = false;
  }
}

// Emotion Tracking for Mental Health Insights
class EmotionTracker {
  static final EmotionTracker _instance = EmotionTracker._internal();
  factory EmotionTracker() => _instance;
  EmotionTracker._internal();

  final List<EmotionResult> _emotionHistory = [];
  final int maxHistorySize = 100;

  void addEmotionResult(EmotionResult result) {
    _emotionHistory.add(result);
    if (_emotionHistory.length > maxHistorySize) {
      _emotionHistory.removeAt(0);
    }
  }

  List<EmotionResult> get recentEmotions => List.unmodifiable(_emotionHistory);

  Map<String, int> getEmotionFrequency({int? lastNResults}) {
    final emotions = lastNResults != null
        ? (lastNResults < _emotionHistory.length
            ? _emotionHistory.sublist(_emotionHistory.length - lastNResults)
            : List<EmotionResult>.from(_emotionHistory))
        : _emotionHistory;

    final frequency = <String, int>{};
    for (final result in emotions) {
      frequency[result.emotion] = (frequency[result.emotion] ?? 0) + 1;
    }
    return frequency;
  }

  double getAverageConfidence({int? lastNResults}) {
    final emotions = lastNResults != null
        ? (lastNResults < _emotionHistory.length
            ? _emotionHistory.sublist(_emotionHistory.length - lastNResults)
            : List<EmotionResult>.from(_emotionHistory))
        : _emotionHistory;

    if (emotions.isEmpty) return 0.0;

    final totalConfidence =
        emotions.fold<double>(0.0, (sum, result) => sum + result.confidence);
    return totalConfidence / emotions.length;
  }

  String getMoodTrend({int? lastNResults}) {
    final emotions = lastNResults != null
        ? (lastNResults < _emotionHistory.length
            ? _emotionHistory.sublist(_emotionHistory.length - lastNResults)
            : List<EmotionResult>.from(_emotionHistory))
        : _emotionHistory;

    if (emotions.length < 2) return 'insufficient_data';

    final positiveEmotions = ['happiness'];
    final neutralEmotions = ['neutral', 'surprise'];
    final negativeEmotions = ['sadness', 'anger', 'fear', 'disgust'];

    int positiveCount = 0;
    int neutralCount = 0;
    int negativeCount = 0;

    for (final emotion in emotions) {
      if (positiveEmotions.contains(emotion.emotion)) {
        positiveCount++;
      } else if (neutralEmotions.contains(emotion.emotion)) {
        neutralCount++;
      } else if (negativeEmotions.contains(emotion.emotion)) {
        negativeCount++;
      }
    }

    if (positiveCount > negativeCount && positiveCount > neutralCount) {
      return 'positive';
    } else if (negativeCount > positiveCount && negativeCount > neutralCount) {
      return 'negative';
    } else if (neutralCount >= positiveCount && neutralCount >= negativeCount) {
      return 'stable';
    } else {
      return 'mixed';
    }
  }

  List<String> getMentalHealthRecommendations() {
    final trend = getMoodTrend(lastNResults: 10);
    final frequency = getEmotionFrequency(lastNResults: 10);

    List<String> recommendations = [];

    switch (trend) {
      case 'positive':
        recommendations.addAll([
          "Great job maintaining positive mental health!",
          "Continue your current self-care practices",
          "Consider sharing your positive energy with others",
        ]);
        break;
      case 'negative':
        recommendations.addAll([
          "Consider reaching out to a mental health professional",
          "Try engaging in mood-boosting activities",
          "Practice self-compassion and patience with yourself",
          "Connect with supportive friends or family",
        ]);
        break;
      case 'stable':
        recommendations.addAll([
          "You're maintaining emotional balance well",
          "Continue monitoring your mental health",
          "Consider setting positive goals for personal growth",
        ]);
        break;
      case 'mixed':
        recommendations.addAll([
          "Your emotions are varied, which is normal",
          "Focus on identifying triggers for negative emotions",
          "Practice mindfulness to stay present",
        ]);
        break;
      default:
        recommendations.add("Keep tracking your emotions for better insights");
    }

    final mostFrequentEmotion = frequency.entries.isNotEmpty
        ? frequency.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : null;

    if (mostFrequentEmotion != null) {
      switch (mostFrequentEmotion) {
        case 'sadness':
          recommendations.add(
              "Try gentle exercise or creative activities to lift your mood");
          break;
        case 'anger':
          recommendations.add(
              "Practice deep breathing or physical exercise to manage anger");
          break;
        case 'fear':
          recommendations.add(
              "Consider anxiety management techniques or professional support");
          break;
        case 'happiness':
          recommendations.add("Share your joy with others and practice gratitude");
          break;
      }
    }

    return recommendations;
  }

  void clearHistory() {
    _emotionHistory.clear();
  }
}