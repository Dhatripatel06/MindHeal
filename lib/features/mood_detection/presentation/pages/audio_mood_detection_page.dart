// lib/features/mood_detection/presentation/pages/audio_mood_detection_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/models/emotion_result.dart';
import '../providers/audio_detection_provider.dart'; // This is now the correct provider
import '../widgets/waveform_visualizer.dart';
import '../widgets/emotion_confidence_bar.dart';
import 'mood_results_page.dart';

class AudioMoodDetectionPage extends StatefulWidget {
  const AudioMoodDetectionPage({super.key});

  @override
  State<AudioMoodDetectionPage> createState() => _AudioMoodDetectionPageState();
}

class _AudioMoodDetectionPageState extends State<AudioMoodDetectionPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  
  // To get the locale for the TTS playback button
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Initialize the provider
    // We can't use context.read in initState, so we do it post-frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioDetectionProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _ttsService.dispose(); // Dispose the TTS service
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Audio Mood Detection',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // --- NEW: Language Selector ---
          Consumer<AudioDetectionProvider>(
            builder: (context, provider, child) {
              return DropdownButton<String>(
                value: provider.selectedLanguage,
                dropdownColor: Colors.teal,
                iconEnabledColor: Colors.white,
                underline: Container(),
                onChanged: provider.isRecording || provider.isProcessing
                    ? null // Disable during recording/processing
                    : (String? newValue) {
                        if (newValue != null) {
                          provider.setLanguage(newValue);
                        }
                      },
                items: <String>['English', 'हिंदी', 'ગુજરાતી']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          // --- END NEW ---
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: context.watch<AudioDetectionProvider>().isRecording
                ? null // Disable during recording
                : _pickAudioFile,
          ),
          SizedBox(width: 10), // Added for spacing
        ],
      ),
      body: Consumer<AudioDetectionProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    // Waveform Visualization Area
                    Container(
                      height: 250, // Increased height
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            WaveformVisualizer(
                              audioData: provider.audioData,
                              isRecording: provider.isRecording,
                              color: Colors.teal,
                            ),
                            
                            // Voice Activity Indicator
                            if (provider.isRecording)
                              Positioned(
                                top: 20,
                                right: 20,
                                child: _buildVoiceActivityIndicator(provider),
                              ),
                            
                            // Recording Timer
                            if (provider.isRecording)
                              Positioned(
                                top: 20,
                                left: 20,
                                child: _buildRecordingTimer(provider),
                              ),
                            
                            // Center Message
                            if (!provider.isRecording && provider.audioData.isEmpty && !provider.hasRecording)
                              const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Tap the microphone to start recording',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Error Message
                    if (provider.lastError != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                           color: Colors.red.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Error: ${provider.lastError}",
                          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                        ),
                      ),

                    // Results Section
                    if (provider.lastResult != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), 
                        padding: const EdgeInsets.all(20),
                         decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildResultsSection(provider),
                      ),
                      
                    // Friendly Response
                    if (provider.isProcessing && provider.friendlyResponse == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(strokeWidth: 2),
                              SizedBox(width: 16),
                              Text(
                                "Your friend is thinking...", 
                                style: TextStyle(fontSize: 16, color: Colors.teal)
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (provider.friendlyResponse != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16), 
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Your friend says:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.volume_up, color: Colors.blue),
                                  onPressed: () {
                                    // Re-speak the last response
                                    _ttsService.speak(
                                      provider.friendlyResponse!, 
                                      provider.currentLocaleId // Use the public getter
                                    );
                                  },
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.friendlyResponse!,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.4, 
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              
              // Control Section
              Container(
                padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
                child: _buildControlSection(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVoiceActivityIndicator(AudioDetectionProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: provider.isVoiceDetected ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            provider.isVoiceDetected ? 'Voice Detected' : 'Listening...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingTimer(AudioDetectionProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              // Only pulse if not already disposed
              if (!_pulseController.isDisposed) {
                 return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              }
              return child!;
            },
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(provider.recordingDuration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(AudioDetectionProvider provider) {
    final result = provider.lastResult!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Voice Analysis Results',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            IconButton(
              onPressed: () => provider.clearResults(),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Dominant Emotion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getEmotionColor(result.emotion).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getEmotionColor(result.emotion).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getEmotionIcon(result.emotion),
                color: _getEmotionColor(result.emotion),
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.emotion.toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getEmotionColor(result.emotion),
                      ),
                    ),
                    Text(
                      '${(result.confidence * 100).toInt()}% Confidence',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // All Emotions
        Text(
          'Emotion Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        
        ...result.allEmotions.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EmotionConfidenceBar(
              emotion: entry.key,
              confidence: entry.value,
              emoji: _getEmotionEmoji(entry.key),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _saveResults(result),
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _viewDetailedResults(result),
                icon: const Icon(Icons.analytics),
                label: const Text('Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlSection(AudioDetectionProvider provider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Recording Button
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: provider.isRecording && !_pulseController.isDisposed ? _pulseAnimation.value : 1.0,
              child: GestureDetector(
                onTap: provider.isProcessing 
                    ? null // Disable tap while processing
                    : (provider.isRecording ? _stopRecording : _startRecording),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: provider.isRecording ? Colors.red : Colors.teal,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (provider.isRecording ? Colors.red : Colors.teal)
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: provider.isProcessing
                      ? const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Icon(
                          provider.isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 48,
                        ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        Text(
          provider.isProcessing
              ? 'Analyzing...'
              : (provider.isRecording ? 'Recording...' : 'Tap to Record'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Secondary Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSecondaryButton(
              icon: Icons.folder_open,
              label: 'Upload',
              onPressed: provider.isRecording || provider.isProcessing
                  ? null 
                  : _pickAudioFile,
            ),
            _buildSecondaryButton(
              icon: Icons.play_arrow,
              label: 'Play',
              onPressed: provider.hasRecording && !provider.isRecording && !provider.isProcessing
                  ? _playRecording 
                  : null,
            ),
            _buildSecondaryButton(
              icon: Icons.delete,
              label: 'Clear',
              onPressed: (provider.hasRecording || provider.lastResult != null) && !provider.isRecording && !provider.isProcessing
                  ? _clearRecording 
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: onPressed != null ? Colors.teal.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: onPressed != null ? Colors.teal.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: onPressed != null ? Colors.teal : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onPressed != null ? Colors.teal : Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _startRecording() async {
    try {
      final provider = context.read<AudioDetectionProvider>();
      await provider.startRecording();
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final provider = context.read<AudioDetectionProvider>();
      
      // --- *** THIS IS THE FIX *** ---
      // We only call stopRecording. The provider handles the analysis.
      await provider.stopRecording();
      // --- *** REMOVED: await provider.analyzeLastRecording(); *** ---
      
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final provider = context.read<AudioDetectionProvider>();
        await provider.analyzeAudioFile(File(result.files.single.path!));
      }
    } catch (e) {
      _showError('Failed to pick audio file: $e');
    }
  }

  Future<void> _playRecording() async {
    try {
      final provider = context.read<AudioDetectionProvider>();
      await provider.playLastRecording();
    } catch (e) {
      _showError('Failed to play recording: $e');
    }
  }

  Future<void> _clearRecording() async {
    final provider = context.read<AudioDetectionProvider>();
    provider.clearRecording();
  }

  void _showAudioSettings() {
    // This was your original function, left as-is.
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
             // ... (Your settings UI) ...
             const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Audio Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveResults(EmotionResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio analysis saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _viewDetailedResults(EmotionResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MoodResultsPage(emotionResult: result),
      ),
    );
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Colors.green;
      case 'sad':
        return Colors.blue;
      case 'angry':
      case 'anger':
        return Colors.red;
      case 'fear':
        return Colors.orange;
      case 'surprise':
        return Colors.purple;
      case 'disgust':
        return Colors.brown;
      case 'neutral':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getEmotionIcon(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'sad':
      case 'sadness':
        return Icons.sentiment_very_dissatisfied;
      case 'angry':
      case 'anger':
        return Icons.sentiment_dissatisfied;
      case 'fear':
        return Icons.sentiment_neutral;
      case 'surprise':
        return Icons.sentiment_satisfied;
      case 'disgust':
        return Icons.sentiment_dissatisfied;
      case 'neutral':
        return Icons.sentiment_neutral;
      default:
        return Icons.sentiment_neutral;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy':
        return '😊';
      case 'sad':
      case 'sadness':
        return '😢';
      case 'angry':
      case 'anger':
        return '😠';
      case 'fear':
        return '😨';
      case 'surprise':
        return '😲';
      case 'disgust':
        return '🤢';
      case 'neutral':
        return '😐';
      default:
        return '😐';
    }
  }
}