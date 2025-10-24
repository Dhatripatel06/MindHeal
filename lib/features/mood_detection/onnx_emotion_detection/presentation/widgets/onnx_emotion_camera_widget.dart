import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../data/services/onnx_emotion_service.dart';
import '../../../data/models/emotion_result.dart';

class OnnxEmotionCameraWidget extends StatefulWidget {
  final bool enableContinuousDetection;
  final Duration detectionInterval;
  final Function(EmotionResult)? onEmotionDetected;
  final bool showPerformanceOverlay;

  const OnnxEmotionCameraWidget({
    super.key,
    this.enableContinuousDetection = false,
    this.detectionInterval = const Duration(milliseconds: 1000),
    this.onEmotionDetected,
    this.showPerformanceOverlay = true,
  });

  @override
  State<OnnxEmotionCameraWidget> createState() =>
      _OnnxEmotionCameraWidgetState();
}

class _OnnxEmotionCameraWidgetState extends State<OnnxEmotionCameraWidget>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isDetecting = false;
  EmotionResult? _lastEmotionResult;
  String _statusMessage = 'Initializing...';

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  final OnnxEmotionService _emotionService = OnnxEmotionService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeServices() async {
    try {
      setState(() => _statusMessage = 'Initializing ONNX emotion detection...');

      // Initialize emotion detection service
      final emotionInitialized = await _emotionService.initialize();
      if (!emotionInitialized) {
        throw Exception('Failed to initialize ONNX emotion detection');
      }

      setState(() => _statusMessage = 'Initializing camera...');

      // Initialize camera
      await _initializeCamera();

      setState(() => _statusMessage = 'Ready for emotion detection');
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Prefer front camera for emotion detection
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Camera ready';
      });

      _fadeController.forward();
    } catch (e) {
      setState(() => _statusMessage = 'Camera error: ${e.toString()}');
    }
  }

  Future<void> _detectEmotion() async {
    if (!_isCameraInitialized || _isDetecting || _cameraController == null) {
      return;
    }

    setState(() => _isDetecting = true);
    _pulseController.repeat(reverse: true);

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();

      // Detect emotions
      final result = await _emotionService.detectEmotions(imageBytes);

      setState(() {
        _lastEmotionResult = result;
        _statusMessage = 'Detected: ${result.emotion} '
            '(${(result.confidence * 100).toStringAsFixed(1)}%)';
      });

      widget.onEmotionDetected?.call(result);

      // Trigger success animation
      _fadeController.reset();
      _fadeController.forward();
    } catch (e) {
      setState(() => _statusMessage = 'Detection error: ${e.toString()}');
    } finally {
      setState(() => _isDetecting = false);
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'anger':
        return Colors.red;
      case 'fear':
        return Colors.orange;
      case 'surprise':
        return Colors.purple;
      case 'disgust':
        return Colors.brown;
      case 'contempt':
        return Colors.indigo;
      case 'neutral':
      default:
        return Colors.grey;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
        return '😢';
      case 'anger':
        return '😠';
      case 'fear':
        return '😨';
      case 'surprise':
        return '😲';
      case 'disgust':
        return '🤢';
      case 'contempt':
        return '😤';
      case 'neutral':
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade900, Colors.blue.shade700],
                ),
              ),
              child: Row(
                children: [
                  if (_isDetecting)
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

            // Camera preview
            Expanded(
              flex: 3,
              child: _buildCameraPreview(),
            ),

            // Emotion results
            if (_lastEmotionResult != null)
              Expanded(
                flex: 2,
                child: _buildEmotionResults(),
              ),

            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Manual detection button
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isDetecting ? _pulseAnimation.value : 1.0,
                            child: ElevatedButton.icon(
                              onPressed: _isDetecting ? null : _detectEmotion,
                              icon: _isDetecting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.camera_alt),
                              label: Text(_isDetecting
                                  ? 'Detecting...'
                                  : 'Detect Emotion'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Switch camera button
                      if (_cameras.length > 1)
                        IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(Icons.flip_camera_ios),
                          iconSize: 32,
                          color: Colors.blue,
                        ),

                      // Performance stats
                      if (_emotionService.isReady &&
                          widget.showPerformanceOverlay)
                        TextButton(
                          onPressed: _showPerformanceStats,
                          child: const Text(
                            'Stats',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildEmotionResults() {
    if (_lastEmotionResult == null) return const SizedBox.shrink();

    final result = _lastEmotionResult!;
    final topEmotions = result.allEmotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topEmotions.take(3).toList();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _getEmotionColor(result.emotion).withOpacity(0.1),
              Colors.grey.shade50,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Dominant emotion
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getEmotionEmoji(result.emotion),
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.emotion,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getEmotionColor(result.emotion),
                      ),
                    ),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Top emotions breakdown
            Text(
              'Emotion Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),

            ...top3.map((emotion) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        emotion.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: emotion.value,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getEmotionColor(emotion.key),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${(emotion.value * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),

            const SizedBox(height: 12),

            // Processing time
            Text(
              'Processed in ${result.processingTimeMs}ms',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    try {
      final currentDirection = _cameraController!.description.lensDirection;
      final newCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection != currentDirection,
      );

      await _cameraController!.dispose();

      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      setState(
          () => _statusMessage = 'Failed to switch camera: ${e.toString()}');
    }
  }

  void _showPerformanceStats() {
    final stats = _emotionService.getPerformanceStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ONNX Performance Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Inferences: ${stats.totalInferences}'),
            const SizedBox(height: 8),
            Text(
                'Average Time: ${stats.averageInferenceTimeMs.toStringAsFixed(1)}ms'),
            Text('Min Time: ${stats.minInferenceTimeMs.toStringAsFixed(1)}ms'),
            Text('Max Time: ${stats.maxInferenceTimeMs.toStringAsFixed(1)}ms'),
            const SizedBox(height: 12),
            Text(
              'Model: EfficientNet-B0 (AFEW)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
