import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../providers/image_detection_provider.dart';
import '../../data/models/emotion_result.dart';

class ImageMoodDetectionPage extends StatefulWidget {
  const ImageMoodDetectionPage({super.key});

  @override
  State<ImageMoodDetectionPage> createState() => _ImageMoodDetectionPageState();
}

class _ImageMoodDetectionPageState extends State<ImageMoodDetectionPage>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late FaceDetector _faceDetector;
  late AnimationController _animationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFaceDetector();
    _initializeAnimations();
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
        enableClassification: true,
        minFaceSize: 0.1,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fabScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _animationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Consumer<ImageDetectionProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              _buildBackgroundWithOverlay(provider),
              _buildCustomAppBar(),
              _buildMainContent(provider),
              _buildActionButtons(provider),
              if (!provider.isServiceInitialized)
                _buildLoadingOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading Emotion Detection Model...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundWithOverlay(ImageDetectionProvider provider) {
    if (provider.selectedImageFile == null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.white,
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            provider.selectedImageFile!,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),
        if (provider.detectedFaces.isNotEmpty && !provider.isAnalyzing)
          Positioned.fill(
            child: CustomPaint(
              painter: PerfectFaceDetectionPainter(
                faces: provider.detectedFaces,
                imageSize: provider.imageSize,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    return SafeArea(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.blue),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'AI Emotion Detection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            GestureDetector(
              onTap: _resetDetection,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh, color: Colors.orange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ImageDetectionProvider provider) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Expanded(
            flex: 3,
            child: _buildImagePreview(provider),
          ),
          Expanded(
            flex: 2,
            child: _buildResultsSection(provider),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ImageDetectionProvider provider) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: provider.selectedImageFile == null
            ? _buildEmptyState()
            : _buildImageWithOverlay(provider),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 60,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'AI Emotion Detection',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Powered by ResEmoteNet model\nSelect an image to analyze emotions with advanced AI',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWithOverlay(ImageDetectionProvider provider) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.0,
          child: Image.file(
            provider.selectedImageFile!,
            fit: BoxFit.cover,
          ),
        ),
        if (provider.isAnalyzing)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AI Analyzing Emotions...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Using ResEmoteNet deep learning model',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!provider.isAnalyzing)
          Positioned(
            top: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: provider.faceDetected
                    ? Colors.green.withOpacity(0.9)
                    : Colors.orange.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (provider.faceDetected ? Colors.green : Colors.orange)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    provider.faceDetected ? Icons.face : Icons.warning,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    provider.faceDetected ? 'Face Detected' : 'No Face',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (provider.errorMessage != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResultsSection(ImageDetectionProvider provider) {
    if (provider.lastResult == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            provider.selectedImageFile == null
                ? 'Select an image to start AI emotion detection'
                : 'Upload an image with a clear human face',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _buildResultCard(provider.lastResult!),
      ),
    );
  }

  Widget _buildResultCard(EmotionResult result) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _getEmotionColor(result.dominantEmotion).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getEmotionColor(result.dominantEmotion),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _getEmotionEmoji(result.dominantEmotion),
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.dominantEmotion.toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _getEmotionColor(result.dominantEmotion),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(result.confidence * 100).toInt()}% Confidence',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Analyzed by ${result.analysisType}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              _buildActionChip(
                icon: Icons.analytics_outlined,
                label: 'Details',
                color: Colors.blue,
                onTap: () => _showDetails(result),
              ),
              _buildActionChip(
                icon: Icons.save_outlined,
                label: 'Save',
                color: Colors.green,
                onTap: () => _saveResult(result),
              ),
              _buildActionChip(
                icon: Icons.share_outlined,
                label: 'Share',
                color: Colors.orange,
                onTap: () => _shareResult(result),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ImageDetectionProvider provider) {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: ScaleTransition(
        scale: _fabScaleAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              icon: Icons.camera_alt,
              label: 'Camera',
              color: Colors.blue,
              onPressed: (provider.isAnalyzing || !provider.isServiceInitialized) 
                  ? null : _captureImage,
            ),
            _buildActionButton(
              icon: Icons.photo_library,
              label: 'Gallery',
              color: Colors.green,
              onPressed: (provider.isAnalyzing || !provider.isServiceInitialized) 
                  ? null : _pickFromGallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ] : null,
      ),
      child: FloatingActionButton.extended(
        heroTag: label.toLowerCase(),
        onPressed: onPressed,
        backgroundColor: onPressed != null ? color : Colors.grey,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      _showErrorDialog('Failed to capture image: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        await _processSelectedImage(File(image.path));
      }
    } catch (e) {
      _showErrorDialog('Failed to pick image: $e');
    }
  }

  Future<void> _processSelectedImage(File imageFile) async {
    final provider = context.read<ImageDetectionProvider>();
    await provider.setSelectedImage(imageFile);
    
    // Validate image has face (optional - model can work without face detection)
    final isValidImage = await _validateImageWithFace(imageFile);
    if (!isValidImage) {
      _showWarningDialog(
        'No human face detected in the image.\nThe AI model will still attempt to analyze emotions, but results may be less accurate.'
      );
    }

    // Analyze with TFLite model
    await provider.analyzeImageWithTFLite(imageFile);
    if (provider.lastResult != null) {
      _animationController.forward();
    }
  }

  Future<bool> _validateImageWithFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      
      final provider = context.read<ImageDetectionProvider>();
      provider.setDetectedFaces(faces);
      
      return faces.isNotEmpty;
    } catch (e) {
      debugPrint('Face detection error: $e');
      return false;
    }
  }

  void _resetDetection() {
    final provider = context.read<ImageDetectionProvider>();
    provider.clearResults();
    _animationController.reset();
    setState(() {});
  }

  void _saveResult(EmotionResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('${result.dominantEmotion} result saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareResult(EmotionResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share, color: Colors.white),
            const SizedBox(width: 8),
            Text('Sharing ${result.dominantEmotion} analysis...'),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDetails(EmotionResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        'AI Emotion Analysis',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Analyzed using ${result.analysisType} model trained on facial emotion recognition',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Emotion Probabilities',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...result.allEmotions.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                _getEmotionEmoji(entry.key),
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.key.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Text(
                                '${(entry.value * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _getEmotionColor(entry.key),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation(
                              _getEmotionColor(entry.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('Error'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_outlined, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text('Warning'),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return '😀';
      case 'surprise':
        return '😮';
      case 'angry':
      case 'anger':
        return '😠';
      case 'sad':
      case 'sadness':
        return '😢';
      case 'disgust':
        return '🤢';
      case 'fear':
        return '😨';
      case 'neutral':
        return '😐';
      default:
        return '😐';
    }
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
      case 'happiness':
        return Colors.green;
      case 'surprise':
        return Colors.purple;
      case 'angry':
      case 'anger':
        return Colors.red;
      case 'sad':
      case 'sadness':
        return Colors.blue;
      case 'disgust':
        return Colors.brown;
      case 'fear':
        return Colors.orange;
      case 'neutral':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}

class PerfectFaceDetectionPainter extends CustomPainter {
  final List<Face> faces;
  final ui.Size imageSize;

  PerfectFaceDetectionPainter({
    required this.faces,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize == ui.Size.zero || faces.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    final scale = math.min(scaleX, scaleY);

    final offsetX = (size.width - imageSize.width * scale) / 2;
    final offsetY = (size.height - imageSize.height * scale) / 2;

    for (final face in faces) {
      final scaledRect = Rect.fromLTRB(
        face.boundingBox.left * scale + offsetX,
        face.boundingBox.top * scale + offsetY,
        face.boundingBox.right * scale + offsetX,
        face.boundingBox.bottom * scale + offsetY,
      );

      canvas.drawRect(scaledRect.translate(2, 2), shadowPaint);
      canvas.drawRect(scaledRect, paint);
      _drawCornerIndicators(canvas, scaledRect, paint);

      paint.style = PaintingStyle.fill;
      for (final landmarkType in [
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.noseBase,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.rightMouth,
      ]) {
        final landmark = face.landmarks[landmarkType];
        if (landmark != null) {
          final scaledOffset = Offset(
            landmark.position.x.toDouble() * scale + offsetX,
            landmark.position.y.toDouble() * scale + offsetY,
          );
          canvas.drawCircle(scaledOffset.translate(1, 1), 6, shadowPaint..style = PaintingStyle.fill);
          canvas.drawCircle(scaledOffset, 5, paint);
        }
      }
      paint.style = PaintingStyle.stroke;
    }
  }

  void _drawCornerIndicators(Canvas canvas, Rect rect, Paint paint) {
    const cornerLength = 20.0;
    const cornerThickness = 4.0;

    final cornerPaint = Paint()
      ..color = paint.color
      ..strokeWidth = cornerThickness
      ..style = PaintingStyle.stroke;

    final corners = [
      [Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top)],
      [Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength)],
      [Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top)],
      [Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength)],
      [Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom)],
      [Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength)],
      [Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom)],
      [Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(PerfectFaceDetectionPainter oldDelegate) {
    return faces != oldDelegate.faces || imageSize != oldDelegate.imageSize;
  }
}