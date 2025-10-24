import 'dart:io';
import 'dart:async'; // Added for Timer
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../onnx_emotion_detection/data/services/onnx_emotion_service.dart';
import '../../data/models/emotion_result.dart';

class ImageDetectionProvider with ChangeNotifier {
  final OnnxEmotionService _emotionService = OnnxEmotionService.instance;

  bool _isInitialized = false;
  bool _isProcessing = false;
  EmotionResult? _currentResult;
  List<EmotionResult> _history = [];
  String? _error;

  // Camera related
  CameraController? _cameraController;
  bool _isRealTimeMode = false;
  Timer? _detectionTimer; // Use a timer instead of image stream

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  EmotionResult? get currentResult => _currentResult;
  List<EmotionResult> get history => _history;
  String? get error => _error;
  bool get isRealTimeMode => _isRealTimeMode;
  CameraController? get cameraController => _cameraController;

  /// Initialize the emotion recognizer
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _error = null;
      notifyListeners();

      _isInitialized = await _emotionService.initialize();

      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      _isInitialized = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Initialize camera for real-time detection
  Future<void> initializeCamera({bool useFrontCamera = true}) async {
    try {
      _error = null;
      notifyListeners();

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      final camera = useFrontCamera
          ? cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => cameras.first,
            )
          : cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      // Set imageFormatGroup to jpeg to ensure takePicture() returns a JPEG
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, 
      );

      await _cameraController!.initialize();
      notifyListeners();
    } catch (e) {
      _error = 'Camera initialization failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Switch camera (front/back)
  Future<void> switchCamera() async {
    if (_cameraController == null) return;
    if (_isRealTimeMode) await stopRealTimeDetection(); // Stop timer before switching

    try {
      final currentDirection = _cameraController!.description.lensDirection;
      final useFront = currentDirection == CameraLensDirection.back;

      await _cameraController?.dispose();
      await initializeCamera(useFrontCamera: useFront);
    } catch (e) {
      _error = 'Failed to switch camera: $e';
      notifyListeners();
    }
  }

  /// Start real-time emotion detection
  Future<void> startRealTimeDetection() async {
    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Initialize camera first');
    }
    if (_isRealTimeMode) return; // Already running

    _isRealTimeMode = true;
    notifyListeners();

    // Start a periodic timer to take pictures
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_isProcessing) return; // Skip if already processing

      try {
        _isProcessing = true;

        // 1. Take a picture
        final XFile imageFile = await _cameraController!.takePicture();
        
        // 2. Read bytes
        final imageBytes = await imageFile.readAsBytes();

        // 3. Process image
        final result = _history.isNotEmpty
            ? await _emotionService.detectEmotionsRealTime(imageBytes,
                previousResult: _history.first,
                stabilizationFactor: 0.3)
            : await _emotionService.detectEmotions(imageBytes);

        _currentResult = result;
        _addToHistory(result);

        // 4. Clean up temp file
        try {
          await File(imageFile.path).delete();
        } catch (e) {
          print('Warning: Failed to delete temp file: $e');
        }

        _isProcessing = false;
        notifyListeners();
      } catch (e) {
        print('Real-time detection error: $e');
        _isProcessing = false;
      }
    });
  }

  /// Stop real-time emotion detection
  Future<void> stopRealTimeDetection() async {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _isRealTimeMode = false;
    _isProcessing = false;
    notifyListeners();
  }

  /// Process single image file
  Future<EmotionResult> processImage(File imageFile) async {
    if (!_isInitialized) {
      throw Exception('Recognizer not initialized');
    }

    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      final imageBytes = await imageFile.readAsBytes();

      final result = _history.isNotEmpty
          ? await _emotionService.detectEmotionsRealTime(imageBytes,
              previousResult: _history.first, stabilizationFactor: 0.2)
          : await _emotionService.detectEmotions(imageBytes);

      _currentResult = result;
      _addToHistory(result);

      _isProcessing = false;
      notifyListeners();

      return result;
    } catch (e) {
      _error = 'Processing failed: $e';
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Process batch of images
  Future<List<EmotionResult>> processBatch(List<File> imageFiles) async {
    if (!_isInitialized) {
      throw Exception('Recognizer not initialized');
    }

    try {
      _isProcessing = true;
      _error = null;
      notifyListeners();

      final imageBytesList = <Uint8List>[];
      for (final file in imageFiles) {
        final bytes = await file.readAsBytes();
        imageBytesList.add(bytes);
      }

      final results = await _emotionService.detectEmotionsBatch(imageBytesList);

      for (final result in results) {
        _addToHistory(result);
      }

      if (results.isNotEmpty) {
        _currentResult = results.last;
      }

      _isProcessing = false;
      notifyListeners();

      return results;
    } catch (e) {
      _error = 'Batch processing failed: $e';
      _isProcessing = false;
      notifyListeners();
      rethrow;
    }
  }

  // _saveCameraImage is no longer needed and has been removed.

  /// Add result to history
  void _addToHistory(EmotionResult result) {
    _history.insert(0, result);
    if (_history.length > 50) {
      _history = _history.take(50).toList();
    }
  }

  /// Clear history
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Get emotion statistics from history
  Map<String, int> getEmotionStatistics() {
    Map<String, int> stats = {};
    for (final result in _history) {
      stats[result.emotion] = (stats[result.emotion] ?? 0) + 1;
    }
    return stats;
  }

  /// Get average confidence
  double getAverageConfidence() {
    if (_history.isEmpty) return 0.0;
    double total = _history.fold(0.0, (sum, result) => sum + result.confidence);
    return total / _history.length;
  }

  /// Get dominant emotion from recent history
  String? getDominantEmotion({int recentCount = 10}) {
    if (_history.isEmpty) return null;

    final recentResults = _history.take(recentCount);
    Map<String, int> emotionCounts = {};

    for (final result in recentResults) {
      emotionCounts[result.emotion] = (emotionCounts[result.emotion] ?? 0) + 1;
    }

    if (emotionCounts.isEmpty) return null;

    return emotionCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Reset state
  void reset() {
    _currentResult = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    // Do not dispose the singleton service here, let it live for the app
    // _emotionService.dispose(); 
    super.dispose();
  }
}