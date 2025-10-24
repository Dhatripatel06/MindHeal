import 'package:flutter/material.dart';
import '../widgets/onnx_emotion_camera_widget.dart';
import '../../../data/models/emotion_result.dart';
import '../../data/services/onnx_emotion_service.dart';

class OnnxEmotionDetectionPage extends StatefulWidget {
  const OnnxEmotionDetectionPage({super.key});

  @override
  State<OnnxEmotionDetectionPage> createState() =>
      _OnnxEmotionDetectionPageState();
}

class _OnnxEmotionDetectionPageState extends State<OnnxEmotionDetectionPage>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late Animation<Color?> _backgroundAnimation;

  final OnnxEmotionService _emotionService = OnnxEmotionService.instance;
  List<EmotionResult> _detectionHistory = [];

  @override
  void initState() {
    super.initState();

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _backgroundAnimation = ColorTween(
      begin: Colors.blue.shade50,
      end: Colors.purple.shade50,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    _backgroundController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  void _handleEmotionDetected(EmotionResult result) {
    setState(() {
      _detectionHistory.insert(0, result);

      // Keep only last 10 detections
      if (_detectionHistory.length > 10) {
        _detectionHistory = _detectionHistory.take(10).toList();
      }
    });

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(_getEmotionEmoji(result.emotion)),
            const SizedBox(width: 8),
            Text('Detected: ${result.emotion}'),
          ],
        ),
        backgroundColor: _getEmotionColor(result.emotion),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
      body: AnimatedBuilder(
        animation: _backgroundAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _backgroundAnimation.value ?? Colors.blue.shade50,
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Main camera widget
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: OnnxEmotionCameraWidget(
                          onEmotionDetected: _handleEmotionDetected,
                          showPerformanceOverlay: true,
                        ),
                      ),
                    ),
                  ),

                  // Detection history
                  if (_detectionHistory.isNotEmpty) _buildDetectionHistory(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios),
                color: Colors.blue.shade700,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'ONNX Emotion Detection',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        'DEMO MODE - Mock Predictions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showAboutDialog,
                icon: const Icon(Icons.info_outline),
                color: Colors.blue.shade700,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Advanced AI-powered emotion recognition using ONNX Runtime',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionHistory() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Recent Detections',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _detectionHistory.length,
              itemBuilder: (context, index) {
                final result = _detectionHistory[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: _getEmotionColor(result.emotion).withOpacity(0.1),
                    border: Border.all(
                      color: _getEmotionColor(result.emotion).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _getEmotionEmoji(result.emotion),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.emotion,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getEmotionColor(result.emotion),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${(result.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final stats = _emotionService.getPerformanceStats();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About ONNX Emotion Detection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Currently running in demo mode with mock predictions',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This feature will use an advanced EfficientNet-B0 model trained on the AFEW dataset to detect emotions in real-time.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Technical Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• Model: EfficientNet-B0 (ONNX)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('• Dataset: AFEW (Acted Facial Expressions)',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('• Input: 224×224×3 RGB images',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              Text('• Runtime: ONNX Runtime Mobile',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              if (stats.totalInferences > 0) ...[
                const Text(
                  'Performance Statistics:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Total detections: ${stats.totalInferences}',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text(
                    'Average time: ${stats.averageInferenceTimeMs.toStringAsFixed(1)}ms',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                Text(
                    'Best time: ${stats.minInferenceTimeMs.toStringAsFixed(1)}ms',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 16),
              const Text(
                'Emotions Detected:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _emotionService.emotionClasses.map((emotion) {
                  return Chip(
                    label: Text(
                      '${_getEmotionEmoji(emotion)} $emotion',
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: _getEmotionColor(emotion).withOpacity(0.1),
                    side: BorderSide(
                      color: _getEmotionColor(emotion).withOpacity(0.3),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
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
