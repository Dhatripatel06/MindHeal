import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mental_wellness_app/features/mood_detection/onnx_emotion_detection/data/services/onnx_emotion_service.dart';
import 'package:mental_wellness_app/features/mood_detection/presentation/widgets/camera_overlay_widget.dart';

class OnnxEmotionCameraWidget extends StatefulWidget {
  final Function(String label, double confidence) onEmotionDetected;

  const OnnxEmotionCameraWidget({
    super.key,
    required this.onEmotionDetected,
  });

  @override
  State<OnnxEmotionCameraWidget> createState() =>
      _OnnxEmotionCameraWidgetState();
}

class _OnnxEmotionCameraWidgetState extends State<OnnxEmotionCameraWidget>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final OnnxEmotionService _emotionService = OnnxEmotionService();
  bool _isInitialized = false;
  bool _isProcessing = false; // Critical fix for Buffer Overflow
  int _lastProcessedTime = 0;
  final int _processIntervalMs = 200; // Throttle to ~5 FPS

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // release camera when app is in background to prevent resource locking crashes
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // Lower resolution for faster AI processing
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() => _isInitialized = true);

      await _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    // 1. Throttling: Check if we are already busy
    if (_isProcessing) return;

    // 2. Throttling: Check if enough time passed since last frame
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - _lastProcessedTime < _processIntervalMs) return;

    _isProcessing = true;
    _lastProcessedTime = currentTime;

    try {
      // Run analysis
      final result = await _emotionService.analyzeFrame(image);

      if (!mounted) return;

      if (result != null) {
        // Only update UI if confidence is significant
        if (result.confidence > 0.40) {
           widget.onEmotionDetected(result.label, result.confidence);
        }
      }
    } catch (e) {
      debugPrint("Error processing frame: $e");
    } finally {
      // Release the lock so next frame can be processed
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        // Use a AspectRatio to ensure preview doesn't stretch
        Center(
          child: CameraPreview(_controller!),
        ),
        const CameraOverlayWidget(),
      ],
    );
  }
}