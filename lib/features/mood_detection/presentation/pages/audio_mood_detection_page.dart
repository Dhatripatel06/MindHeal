import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart'; // Needed for playback
import '../../data/models/emotion_result.dart';
import '../providers/audio_detection_provider.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/emotion_confidence_bar.dart';
import '../widgets/advice_dialog.dart'; // Reusing your existing AdviceDialog
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
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late AnimationController _contentAnimationController;
  late Animation<double> _fadeAnimation;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AudioDetectionProvider>();
      if (!provider.isInitialized) {
        provider.initialize();
      }
    });
  }

  void _initializeAnimations() {
    // Pulse animation for recording button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.elasticOut),
    );
    _fabAnimationController.forward();

    // Content fade-in animation
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _contentAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fabAnimationController.dispose();
    _contentAnimationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Helper to play/pause the recorded audio ---
  Future<void> _togglePlayback(String? filePath) async {
    if (filePath == null) return;
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
        _audioPlayer.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
                if(mounted) setState(() => _isPlaying = false);
            }
        });
      }
      setState(() {
        _isPlaying = !_isPlaying;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error playing audio: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          _buildBackground(),
          _buildCustomAppBar(),
          _buildMainContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.teal.shade50, Colors.white],
        ),
      ),
    );
  }

  Widget _buildCustomAppBar() {
    return SafeArea(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildAppBarButton(
              icon: Icons.arrow_back,
              color: Colors.teal,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Voice Mood Analyst',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            // Language Selector
            Consumer<AudioDetectionProvider>(
              builder: (context, provider, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: DropdownButton<String>(
                    value: provider.selectedLanguage,
                    icon: const Icon(Icons.language, color: Colors.teal, size: 20),
                    underline: Container(),
                    isDense: true,
                    style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                    onChanged: provider.isRecording || provider.isProcessing
                        ? null
                        : (val) => provider.setLanguage(val!),
                    items: ['English', 'हिंदी', 'ગુજરાતી'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: color),
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<AudioDetectionProvider>(
      builder: (context, provider, child) {
        
        // Trigger animation when result arrives
        if (provider.lastResult != null && _contentAnimationController.status != AnimationStatus.completed) {
          _contentAnimationController.forward();
        }

        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80), // Spacing for AppBar
              
              // 1. Dynamic Visualizer Area
              Expanded(
                flex: 4,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.teal.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The Waveform
                        WaveformVisualizer(
                          audioData: provider.audioData,
                          isRecording: provider.isRecording,
                          color: provider.isRecording ? Colors.redAccent : Colors.teal,
                        ),

                        // Placeholder Icon when idle
                        if (!provider.isRecording && provider.audioData.isEmpty && !provider.hasRecording)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq, size: 80, color: Colors.teal.shade100),
                              const SizedBox(height: 16),
                              Text(
                                "Tap mic to start speaking",
                                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                              ),
                            ],
                          ),
                        
                        // Processing Indicator
                        if (provider.isProcessing)
                          Container(
                            color: Colors.black54,
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: Colors.white),
                                  SizedBox(height: 16),
                                  Text("Analyzing Tone & Voice...", style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          
                        // Timer Overlay
                        if (provider.isRecording)
                          Positioned(
                            top: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatDuration(provider.recordingDuration),
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 2. Transcript & Playback Area (If recording exists)
              if (provider.hasRecording)
                 Expanded(
                    flex: 2,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "You said:",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                // Playback Button
                                GestureDetector(
                                  onTap: () => _togglePlayback(provider.audioFilePath),
                                  child: Icon(
                                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                                    color: Colors.teal,
                                    size: 28,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  provider.liveTranscribedText.isEmpty 
                                    ? "(Audio processed, analyzing tone...)" 
                                    : provider.liveTranscribedText,
                                  style: const TextStyle(fontSize: 16, height: 1.4, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                 ),

              // 3. Results Area (Shows only after analysis)
              if (provider.lastResult != null)
                Expanded(
                  flex: 4,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildResultCard(provider.lastResult!),
                  ),
                )
              else 
                const Spacer(flex: 2),

              // 4. Bottom Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Upload Button
                    _buildCircleButton(
                      icon: Icons.folder_open_rounded,
                      color: Colors.blueGrey,
                      onPressed: provider.isRecording ? null : _pickAudioFile,
                    ),
                    
                    // Main Record Button
                    ScaleTransition(
                      scale: provider.isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                      child: GestureDetector(
                        onTap: provider.isProcessing 
                            ? null 
                            : (provider.isRecording ? _stopRecording : _startRecording),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: provider.isRecording 
                                ? [Colors.red.shade400, Colors.red.shade600]
                                : [Colors.teal.shade400, Colors.teal.shade600],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (provider.isRecording ? Colors.red : Colors.teal).withOpacity(0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Icon(
                            provider.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                    ),

                    // Clear Button
                    _buildCircleButton(
                      icon: Icons.refresh_rounded,
                      color: Colors.orange,
                      onPressed: provider.isRecording ? null : () {
                        provider.clearResults();
                        provider.clearRecording();
                        _contentAnimationController.reset();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircleButton({required IconData icon, required Color color, required VoidCallback? onPressed}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: onPressed != null ? color : Colors.grey[300]),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildResultCard(EmotionResult result) {
    final confidenceColor = _getAccuracyColor(result.confidence);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emotion Icon & Label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getEmotionEmoji(result.emotion),
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Text(
                  result.emotion.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getEmotionColor(result.emotion),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Confidence Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${(result.confidence * 100).toInt()}% Confidence",
                style: TextStyle(color: confidenceColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons (Save, Details, ADVISER)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildActionChip(
                  icon: Icons.analytics_outlined,
                  label: 'Details',
                  color: Colors.blue,
                  onTap: () => _viewDetailedResults(result),
                ),
                // *** THE ADVISER BUTTON ***
                _buildActionChip(
                  icon: Icons.psychology,
                  label: 'MindHeal Adviser',
                  color: Colors.purple,
                  onTap: () => _getConversationalAdvice(context), 
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // --- Logic Methods ---

  Future<void> _startRecording() async {
    try {
      await context.read<AudioDetectionProvider>().startRecording();
    } catch (e) {
      _showError('Recording failed: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await context.read<AudioDetectionProvider>().stopRecording();
    } catch (e) {
      _showError('Stop failed: $e');
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        await context.read<AudioDetectionProvider>().analyzeAudioFile(File(result.files.single.path!));
      }
    } catch (e) {
      _showError('Pick failed: $e');
    }
  }

  void _viewDetailedResults(EmotionResult result) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MoodResultsPage(emotionResult: result)));
  }

  // --- *** THE "VIRTUAL FRIEND" LOGIC *** ---
  void _getConversationalAdvice(BuildContext context) {
    final provider = context.read<AudioDetectionProvider>();
    final result = provider.lastResult;
    final userText = provider.liveTranscribedText;

    if (result == null) return;

    // We re-use the AdviceDialog but with a slight tweak to pass user text
    // Since AdviceDialog uses GeminiAdviserService internally, we need to ensure 
    // we trigger the "Conversational" mode. 
    // For now, we will use the existing AdviceDialog but enhance the prompt context.
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdviceDialog(
        emotionResult: result,
        // You might need to update AdviceDialog to accept 'userSpeech' text
        // or we pass it as "context" if your AdviceDialog supports it.
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  Color _getAccuracyColor(double confidence) {
    if (confidence > 0.8) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.green;
      case 'sad': return Colors.blue;
      case 'angry': return Colors.red;
      case 'neutral': return Colors.grey;
      default: return Colors.purple;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return '😊';
      case 'sad': return '😢';
      case 'angry': return '😠';
      case 'neutral': return '😐';
      default: return '🤔';
    }
  }
}