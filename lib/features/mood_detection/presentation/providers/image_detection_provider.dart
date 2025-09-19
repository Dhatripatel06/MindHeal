import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../data/models/emotion_result.dart';
import '../../data/services/tflite_service.dart';

class ImageDetectionProvider extends ChangeNotifier {
  File? _selectedImageFile;
  ui.Image? _uiImage;
  bool _isAnalyzing = false;
  bool _faceDetected = false;
  EmotionResult? _lastResult;
  List<Face> _detectedFaces = [];
  Map<String, double> _emotions = {};
  String? _errorMessage;
  Size _imageSize = Size.zero;
  
  late tfliteService _tfliteService;
  bool _isServiceInitialized = false;

  ImageDetectionProvider() {
    _tfliteService = tfliteService();
    _initializeService();
  }

  // Getters
  File? get selectedImageFile => _selectedImageFile;
  ui.Image? get uiImage => _uiImage;
  bool get isAnalyzing => _isAnalyzing;
  bool get faceDetected => _faceDetected;
  EmotionResult? get lastResult => _lastResult;
  List<Face> get detectedFaces => _detectedFaces;
  Map<String, double> get emotions => _emotions;
  String? get errorMessage => _errorMessage;
  Size get imageSize => _imageSize;
  bool get isServiceInitialized => _isServiceInitialized;

  Future<void> _initializeService() async {
    try {
      print('🔧 Initializing TFLite service...');
      _isServiceInitialized = await tfliteService.initialize();
      if (_isServiceInitialized) {
        print('✅ TFLite service ready for emotion detection');
        _errorMessage = null;
      } else {
        print('❌ Failed to initialize TFLite service');
        _errorMessage = 'Failed to initialize emotion detection model';
      }
      notifyListeners();
    } catch (e) {
      print('❌ Error initializing TFLite service: $e');
      _isServiceInitialized = false;
      _errorMessage = 'Model initialization failed: $e';
      notifyListeners();
    }
  }

  // Set selected image
  Future<void> setSelectedImage(File imageFile) async {
    _selectedImageFile = imageFile;
    _errorMessage = null;
    
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _uiImage?.dispose();
      _uiImage = frame.image;
      _imageSize = Size(_uiImage!.width.toDouble(), _uiImage!.height.toDouble());
      print('📷 Image loaded: ${_imageSize.width}x${_imageSize.height}');
    } catch (e) {
      print('❌ Error loading UI image: $e');
      _errorMessage = 'Failed to load image';
    }
    
    notifyListeners();
  }

  // Set detected faces
  void setDetectedFaces(List<Face> faces) {
    _detectedFaces = faces;
    _faceDetected = faces.isNotEmpty;
    print('👤 Detected ${faces.length} face(s)');
    notifyListeners();
  }

  // Set analyzing state
  void setAnalyzing(bool analyzing) {
    _isAnalyzing = analyzing;
    notifyListeners();
  }

  // Set result
  void setResult(EmotionResult result) {
    _lastResult = result;
    _emotions = result.allEmotions;
    _errorMessage = null;
    notifyListeners();
  }

  // Analyze image using TFLite model
  Future<Object> analyzeImageWithTFLite(File imageFile) async {
    if (!_isServiceInitialized) {
      _errorMessage = 'Emotion detection model not ready. Please wait...';
      notifyListeners();
      
      // Try to reinitialize
      await _initializeService();
      
      if (!_isServiceInitialized) {
        _errorMessage = 'Failed to initialize model. Using demo mode.';
        final fallbackResult = _getFallbackResult();
        setResult(fallbackResult);
        return fallbackResult;
      }
    }

    setAnalyzing(true);
    
    try {
      print('🤖 Starting TFLite emotion analysis...');
      final result = await tfliteService.analyzeImage(imageFile);
      
      // ignore: unnecessary_null_comparison
      if (result != null) {
        setResult(result as EmotionResult);
        return result;
      } else {
        _errorMessage = 'Failed to analyze emotions - using demo results';
        // Fallback to demo result for testing
        final fallbackResult = _getFallbackResult();
        setResult(fallbackResult);
        return fallbackResult;
      }
      
    } catch (e) {
      print('❌ Error in TFLite analysis: $e');
      _errorMessage = 'Analysis error: $e';
      final fallbackResult = _getFallbackResult();
      setResult(fallbackResult);
      return fallbackResult;
    } finally {
      setAnalyzing(false);
    }
  }

  // Backward compatibility method
  Future<void> analyzeImage(File imageFile) async {
    await analyzeImageWithTFLite(imageFile);
  }

  // Fallback emotion analysis for testing
  EmotionResult _getFallbackResult() {
    final emotions = <String, double>{
      'happy': 0.35 + (DateTime.now().millisecond % 30) / 100,
      'surprise': 0.15 + (DateTime.now().millisecond % 20) / 100,
      'angry': 0.10 + (DateTime.now().millisecond % 15) / 100,
      'sad': 0.15 + (DateTime.now().millisecond % 25) / 100,
      'disgust': 0.05 + (DateTime.now().millisecond % 10) / 100,
      'fear': 0.10 + (DateTime.now().millisecond % 15) / 100,
      'neutral': 0.10 + (DateTime.now().millisecond % 15) / 100,
    };

    final dominantEmotion = emotions.entries.reduce(
      (a, b) => a.value > b.value ? a : b
    );

    return EmotionResult(
      dominantEmotion: dominantEmotion.key,
      confidence: dominantEmotion.value,
      allEmotions: emotions,
      timestamp: DateTime.now(),
      analysisType: 'demo_fallback',
    );
  }

  // Clear all results
  void clearResults() {
    _selectedImageFile = null;
    _uiImage?.dispose();
    _uiImage = null;
    _lastResult = null;
    _emotions = {};
    _detectedFaces = [];
    _faceDetected = false;
    _errorMessage = null;
    _isAnalyzing = false;
    _imageSize = Size.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    tfliteService.dispose();
    super.dispose();
  }
}