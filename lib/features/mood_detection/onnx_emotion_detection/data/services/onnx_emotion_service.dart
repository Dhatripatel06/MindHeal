import 'dart:developer';
import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';

class OnnxEmotionService {
  OrtSession? _session;
  List<String> _labels = [];
  bool _isInitialized = false;

  // Singleton pattern
  static final OnnxEmotionService _instance = OnnxEmotionService._internal();
  factory OnnxEmotionService() => _instance;
  OnnxEmotionService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      log('🚀 Initializing OnnxEmotionService...');
      OrtEnv.instance.init();
      _session = await _loadSession();
      await _loadEmotionClasses();
      _isInitialized = true;
      log('✅ OnnxEmotionService Initialized.');
    } catch (e) {
      log('❌ Error initializing OnnxEmotionService: $e');
    }
  }

  Future<OrtSession> _loadSession() async {
    const assetName = 'assets/models/enet_b0_8_best_afew.onnx';
    final rawAsset = await rootBundle.load(assetName);
    final bytes = rawAsset.buffer.asUint8List();
    final sessionOptions = OrtSessionOptions();
    // Optimized for CPU to prevent crashing on unsupported GPUs
    // sessionOptions.setInterOpNumThreads(1); 
    // sessionOptions.setIntraOpNumThreads(1);
    
    return OrtSession.fromBuffer(bytes, sessionOptions);
  }

  Future<void> _loadEmotionClasses() async {
    try {
      final labelsData = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsData.split('\n').where((l) => l.isNotEmpty).map((l) => l.trim()).toList();
    } catch (e) {
      log('⚠️ Could not load labels, using defaults.');
      _labels = ['Neutral', 'Happy', 'Sad', 'Surprise', 'Fear', 'Disgust', 'Anger', 'Contempt'];
    }
  }

  Future<EmotionResult?> analyzeFrame(CameraImage image) async {
    if (!_isInitialized || _session == null) return null;

    try {
      // 1. Preprocess Image (Convert YUV/BGRA to float32 tensor)
      // Note: This is heavy processing. In a production app, 
      // this specific conversion should happen in a separate Isolate.
      final inputFloats = _preprocessCameraImage(image);
      
      if (inputFloats == null) return null;

      // 2. Create Tensor
      // Model expects [1, 3, 224, 224]
      final shape = [1, 3, 224, 224]; 
      final inputOrt = OrtValueTensor.createTensorWithDataList(inputFloats, shape);
      
      // 3. Inference
      final runOptions = OrtRunOptions();
      final inputs = {'input.1': inputOrt}; // Check your model's input name using Netron
      final outputs = _session!.run(runOptions, inputs);

      // 4. Post-process
      // Assuming output is '357' or similar key, getting the first output
      final outputTensor = outputs[0]?.value as List<List<double>>; 
      final probabilities = outputTensor[0];
      
      // Cleanup
      inputOrt.release();
      runOptions.release();
      for (var element in outputs) {
        element?.release();
      }

      return _getTopEmotion(probabilities);
    } catch (e) {
      // Suppress logs for frame errors to avoid console spam
      return null;
    }
  }

  // Helper: Basic Preprocessing (Simplified for stability)
  List<double>? _preprocessCameraImage(CameraImage image) {
    // TODO: For optimal performance, move YUV->RGB conversion to C++ (FFI) or use a computed isolate.
    // Current implementation is a placeholder for the logic logic needed to
    // resize and normalize to 224x224 RGB [0-1] range.
    
    // Returning null safely if image format is not handled to prevent crash
    if (image.planes.isEmpty) return null;
    
    // Placeholder: If you have the image conversion logic here, ensure it returns 
    // a flat list of 150528 doubles (1 * 3 * 224 * 224).
    // For now, we return null to prevent the logic crash until you plug in the image utils.
    // You usually use the `image` package or `google_mlkit_commons` for rotation/conversion.
    return null; 
  }

  EmotionResult _getTopEmotion(List<double> logits) {
    // Softmax logic if model outputs raw logits
    double maxVal = -double.infinity;
    int maxIdx = -1;

    for (int i = 0; i < logits.length; i++) {
      if (logits[i] > maxVal) {
        maxVal = logits[i];
        maxIdx = i;
      }
    }
    
    // If you need actual softmax probability:
    // double sum = 0.0;
    // var exps = logits.map(math.exp).toList();
    // exps.forEach((e) => sum += e);
    // var probs = exps.map((e) => e / sum).toList();
    
    String label = (maxIdx >= 0 && maxIdx < _labels.length) ? _labels[maxIdx] : "Unknown";
    return EmotionResult(label: label, confidence: 1.0); // returning max as 1.0 for simplicity
  }
  
  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _isInitialized = false;
  }
}