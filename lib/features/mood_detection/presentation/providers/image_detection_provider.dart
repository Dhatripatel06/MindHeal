// File: lib/features/mood_detection/presentation/providers/image_detection_provider.dart
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart'; // <-- 1. IMPORT (MODIFIED)
import '../../onnx_emotion_detection/data/services/onnx_emotion_service.dart';
import '../../data/models/emotion_result.dart';

// --- 2. IMPORT THE CORRECT SERVICE (MODIFIED) ---
import '../../../../core/services/gemini_adviser_service.dart';

class ImageDetectionProvider with ChangeNotifier {
  final OnnxEmotionService _emotionService = OnnxEmotionService.instance;

  // --- 3. USE THE CORRECT SERVICES (MODIFIED) ---
  final GeminiAdviserService _geminiService = GeminiAdviserService();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isInitialized = false;
  bool _isProcessing = false;
  EmotionResult? _currentResult;
  List<EmotionResult> _history = [];
  String? _error;

  // Camera related
  CameraController? _cameraController;
  bool _isRealTimeMode = false;
  Timer? _detectionTimer;

  // Advice & TTS State
  String? _adviceText;
  bool _isFetchingAdvice = false;
  String _selectedLanguage = 'English';
  final List<String> _availableLanguages = ['English', 'हिंदी', 'ગુજરાતી'];
  bool _isSpeaking = false; // <-- 4. SIMPLIFIED TTS STATE (MODIFIED)

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  EmotionResult? get currentResult => _currentResult;
  List<EmotionResult> get history => _history;
  String? get error => _error;
  bool get isRealTimeMode => _isRealTimeMode;
  CameraController? get cameraController => _cameraController;

  // Advice & TTS Getters
  String? get adviceText => _adviceText;
  bool get isFetchingAdvice => _isFetchingAdvice;
  String get selectedLanguage => _selectedLanguage;
  List<String> get availableLanguages => _availableLanguages;
  bool get isSpeaking => _isSpeaking; // <-- 5. UPDATED GETTER (MODIFIED)

  ImageDetectionProvider() {
    // --- 6. CONFIGURE FLUTTER_TTS (MODIFIED) ---
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _flutterTts.setErrorHandler((msg) {
      print('TTS Error: $msg');
      _isSpeaking = false;
      notifyListeners();
    });
  }

  /// Initialize the emotion recognizer
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _error = null;
      notifyListeners();

      // --- FIX 1: Use initialize from main.dart ---
      // The service is now initialized in main.dart
      // _isInitialized = await _emotionService.initialize();

      // We just check if the singleton is initialized
      _isInitialized = _emotionService.isInitialized;
      if (!_isInitialized) {
        print("Waiting for OnnxEmotionService to be initialized from main...");
        // This is a fallback in case provider is created before main init is done
        await _emotionService.initialize();
        _isInitialized = _emotionService.isInitialized;
      }

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
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      print("Camera already initialized.");
      return;
    }
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
    if (_isRealTimeMode) await stopRealTimeDetection();

    try {
      final currentDirection = _cameraController!.description.lensDirection;
      final useFront = currentDirection == CameraLensDirection.back;

      await _cameraController?.dispose();
      _cameraController = null;
      notifyListeners();
      await initializeCamera(useFrontCamera: useFront);
    } catch (e) {
      _error = 'Failed to switch camera: $e';
      notifyListeners();
    }
  }

  /// Start real-time emotion detection
  Future<void> startRealTimeDetection() async {
    if (!_isInitialized ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      throw Exception('Initialize camera first');
    }
    if (_isRealTimeMode) return;

    _isRealTimeMode = true;
    notifyListeners();

    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_isProcessing || !_isRealTimeMode) return;

      try {
        _isProcessing = true;
        final XFile imageFile = await _cameraController!.takePicture();
        final imageBytes = await imageFile.readAsBytes();

        final result = _history.isNotEmpty
            ? await _emotionService.detectEmotionsRealTime(imageBytes,
                previousResult: _history.first,
                stabilizationFactor: 0.3)
            : await _emotionService.detectEmotions(imageBytes);

        // Clear advice if mood changes
        if (_currentResult?.emotion != result.emotion) {
          _adviceText = null;
        }

        _currentResult = result;
        _addToHistory(result);

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
        // Optionally set error state
        // _error = 'Detection failed: $e';
        // notifyListeners();
      }
    });
  }

  /// Stop real-time emotion detection
  Future<void> stopRealTimeDetection() async {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _isRealTimeMode = false;
    _isProcessing = false;
    await _flutterTts.stop(); // <-- 7. USE FLUTTER_TTS (MODIFIED)
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
      _adviceText = null;
      notifyListeners();

      final imageBytes = await imageFile.readAsBytes();

      final result = _history.isNotEmpty
          ? await _emotionService.detectEmotionsRealTime(imageBytes,
              previousResult: _history.first, stabilizationFactor: 0.2)
          : await _emotionService.detectEmotions(imageBytes);

      _currentResult = result; // Set this result as the current one
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
      _adviceText = null;
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
        _currentResult = results.last; // Set the last result as current
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

  /// Set the language for advice and TTS
  void setLanguage(String language) {
    if (_availableLanguages.contains(language)) {
      _selectedLanguage = language;
      _adviceText = null; // Clear advice when language changes
      _flutterTts.stop(); // <-- 8. USE FLUTTER_TTS (MODIFIED)
      notifyListeners();
    }
  }

  /// Fetch advice from Gemini based on the current mood and selected language
  Future<void> fetchAdvice() async {
    // Use the provider's currentResult as the context for advice
    final moodToAdvise = _currentResult?.emotion;
    final confidence = _currentResult?.confidence ?? 0.0;

    if (moodToAdvise == null ||
        moodToAdvise == 'none' ||
        (_currentResult?.hasError ?? false)) {
      _adviceText = "Detect a valid mood first to get advice.";
      notifyListeners();
      return;
    }
    // --- 9. USE isConfigured FROM THE CORRECT SERVICE (MODIFIED) ---
    if (!_geminiService.isConfigured) {
      _adviceText = "Advice service is unavailable. Check API key.";
      notifyListeners();
      return;
    }

    _isFetchingAdvice = true;
    _adviceText = null; // Clear previous advice while fetching
    _error = null; // Clear previous errors
    await _flutterTts.stop(); // <-- 10. USE FLUTTER_TTS (MODIFIED)
    notifyListeners(); // Show loading state

    try {
      // --- 11. CALL THE CORRECT METHOD (MODIFIED) ---
      final advice = await _geminiService.getEmotionalAdvice(
        detectedEmotion: moodToAdvise,
        confidence: confidence, // Pass confidence
        language: _selectedLanguage,
      );
      _adviceText = advice;
    } catch (e) {
      _adviceText = "Error fetching advice: $e";
      _error = _adviceText; // Also set general error
    } finally {
      _isFetchingAdvice = false;
      notifyListeners(); // Update UI with advice or error
    }
  }

  /// Speak the current advice text using TTS
  Future<void> speakAdvice() async {
    // --- 12. FULLY REWRITTEN TTS LOGIC (MODIFIED) ---
    if (_adviceText != null &&
        _adviceText!.isNotEmpty &&
        !_adviceText!.startsWith("Error") &&
        !_isSpeaking) {
      String langCode = 'en-US'; // Default
      if (_selectedLanguage == 'हिंदी') langCode = 'hi-IN';
      if (_selectedLanguage == 'ગુજરાતી') langCode = 'gu-IN';

      await _flutterTts.setLanguage(langCode);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.speak(_adviceText!);
    } else if (_isSpeaking) {
      await _flutterTts.pause(); // Or stop()
    } else {
      print("No valid advice text to speak or already speaking.");
    }
  }

  /// Stop TTS
  Future<void> stopSpeaking() async {
    await _flutterTts.stop(); // <-- 13. USE FLUTTER_TTS (MODIFIED)
    _isSpeaking = false;
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

  /// Reset ALL state (detection results, advice, errors)
  void reset() {
    _currentResult = null;
    _error = null;
    _adviceText = null;
    _isFetchingAdvice = false;
    _flutterTts.stop(); // <-- 14. USE FLUTTER_TTS (MODIFIED)
    // Don't reset _selectedLanguage, keep user's preference
    notifyListeners();
  }

  // --- NEW METHOD ---
  /// Resets only the advice-related state, typically called when navigating to a new result page.
  void resetAdviceStateOnly() {
    _adviceText = null;
    _isFetchingAdvice = false;
    _flutterTts.stop(); // <-- 15. USE FLUTTER_TTS (MODIFIED)
    _isSpeaking = false;
    notifyListeners();
  }
  // --- END NEW METHOD ---

  // --- 16. FULLY REWRITTEN fetchAdviceForMood (MODIFIED) ---
  /// Fetch advice from Gemini specifically for the given mood.
  Future<void> fetchAdviceForMood(String mood) async {
    if (mood.isEmpty || mood == 'none' || mood.startsWith("Error")) {
      _adviceText = "Error: Cannot get advice for an unknown or error mood.";
      _isFetchingAdvice = false;
      notifyListeners();
      return;
    }

    // Check if the service is configured (this now checks the API key!)
    if (!_geminiService.isConfigured) {
      _adviceText = "Error: Advice service is not configured (Check API Key).";
      _isFetchingAdvice = false;
      notifyListeners();
      return;
    }

    _isFetchingAdvice = true;
    _adviceText = null; // Clear previous advice while fetching
    _error = null; // Clear previous errors
    await _flutterTts.stop();
    notifyListeners(); // Show loading state

    try {
      // Find the confidence for this mood, or default to 1.0
      double confidence = _currentResult?.allEmotions[mood] ?? 1.0;
      if (mood == _currentResult?.emotion) {
         confidence = _currentResult?.confidence ?? 1.0;
      }

      final advice = await _geminiService.getEmotionalAdvice(
        detectedEmotion: mood,
        confidence: confidence, // Pass the correct confidence
        language: _selectedLanguage,
      );

      _adviceText = advice;
      
      if (advice.contains("Error") || advice.contains("Sorry")) {
        _error = advice;
      }

    } catch (e) {
      _adviceText = "Error: $e"; // Ensure error message starts with "Error"
      _error = _adviceText;
      print("Error fetching advice for mood $mood: $e");
    } finally {
      _isFetchingAdvice = false;
      notifyListeners(); // Update UI with advice or error
    }
  }
  // --- END OF METHODS TO ADD ---

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();

    // --- FIX 2: DO NOT DISPOSE THE TTS SERVICE ---
    // This prevents the crash when navigating to other pages.
    // _ttsService.dispose();
    
    // We also don't dispose the FlutterTts singleton
    _flutterTts.stop();

    super.dispose();
  }
}