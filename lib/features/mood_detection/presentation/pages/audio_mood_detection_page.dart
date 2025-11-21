import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/models/emotion_result.dart';
import '../providers/audio_detection_provider.dart';
import '../widgets/waveform_visualizer.dart';
import '../widgets/advice_dialog.dart';

class AudioMoodDetectionPage extends StatefulWidget {
  const AudioMoodDetectionPage({super.key});

  @override
  State<AudioMoodDetectionPage> createState() => _AudioMoodDetectionPageState();
}

class _AudioMoodDetectionPageState extends State<AudioMoodDetectionPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _playerSubscription; // Fix: Manage subscription
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this)..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    
    _fadeController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AudioDetectionProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _playerSubscription?.cancel(); // Fix: Cancel stream listener
    _audioPlayer.dispose(); // Dispose player first
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback(String? filePath) async {
    if (filePath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        // Cancel old listener if exists
        _playerSubscription?.cancel();
        
        await _audioPlayer.setFilePath(filePath);
        await _audioPlayer.play();
        
        if (mounted) setState(() => _isPlaying = true);
        
        // Fix: Assign to subscription variable
        _playerSubscription = _audioPlayer.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            if (mounted) setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      print("Playback error: $e");
      if (mounted) setState(() => _isPlaying = false);
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
            _buildAppBarButton(icon: Icons.arrow_back, color: Colors.teal, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 16),
            const Expanded(child: Text('Voice Mood Analyst', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))),
            Consumer<AudioDetectionProvider>(
              builder: (context, provider, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.teal.shade200)),
                child: DropdownButton<String>(
                  value: provider.selectedLanguage,
                  icon: const Icon(Icons.language, color: Colors.teal, size: 20),
                  underline: const SizedBox(),
                  isDense: true,
                  style: TextStyle(color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                  onChanged: provider.isRecording ? null : (v) => provider.setLanguage(v!),
                  items: ['English', 'हिंदी', 'ગુજરાતી'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                ),
              ),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Icon(icon, color: color),
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<AudioDetectionProvider>(
      builder: (context, provider, child) {
        if (provider.lastResult != null && _fadeController.status != AnimationStatus.completed) {
          _fadeController.forward();
        }

        return SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),
              
              // 1. Visualizer
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: provider.lastResult != null ? 180 : 300,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      WaveformVisualizer(
                        audioData: provider.audioData,
                        isRecording: provider.isRecording,
                        color: provider.isRecording ? Colors.redAccent : Colors.teal,
                      ),
                      if (!provider.isRecording && !provider.hasRecording)
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.mic, size: 60, color: Colors.teal.shade100),
                          const SizedBox(height: 10),
                          Text("Tap mic to speak", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                        ]),
                      if (provider.isProcessing)
                        Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
                      if (provider.isRecording)
                         Positioned(top: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(_formatDuration(provider.recordingDuration), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),
              ),

              // 2. Transcript & Result
              Expanded(
                child: provider.lastResult != null
                    ? FadeTransition(opacity: _fadeAnimation, child: _buildResultsView(provider))
                    : const SizedBox(),
              ),

              // 3. Bottom Controls
              _buildBottomControls(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsView(AudioDetectionProvider provider) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Transcript
        if (provider.liveTranscribedText.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.teal.shade100)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text("You said:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                const Spacer(),
                GestureDetector(
                  onTap: () => _togglePlayback(provider.audioFilePath),
                  child: Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.teal),
                )
              ]),
              const SizedBox(height: 8),
              Text(provider.liveTranscribedText, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
            ]),
          ),

        // Result Card
        if (provider.lastResult != null)
          _buildResultCard(provider.lastResult!),
      ],
    );
  }

  Widget _buildResultCard(EmotionResult result) {
    final color = _getEmotionColor(result.emotion);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Stack(alignment: Alignment.center, children: [
             SizedBox(width: 80, height: 80, child: CircularProgressIndicator(value: result.confidence, strokeWidth: 6, color: color, backgroundColor: color.withOpacity(0.2))),
             Container(width: 65, height: 65, decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: color, width: 2)), child: Center(child: Text(_getEmotionEmoji(result.emotion), style: const TextStyle(fontSize: 28)))),
          ]),
          const SizedBox(height: 16),
          Text(result.emotion.toUpperCase(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
             Icon(Icons.verified, color: color, size: 18),
             const SizedBox(width: 6),
             Text("${(result.confidence * 100).toInt()}% Confidence", style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 20),
          Wrap(spacing: 8, children: [
             _buildActionChip(icon: Icons.analytics_outlined, label: 'Details', color: Colors.blue, onTap: () => _showDetailsSheet(result)),
             _buildActionChip(icon: Icons.psychology, label: 'Adviser', color: Colors.purple, onTap: () => _getConversationalAdvice(context)),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionChip({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildBottomControls(AudioDetectionProvider provider) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(icon: const Icon(Icons.folder_open, color: Colors.blueGrey), onPressed: provider.isRecording ? null : _pickAudioFile),
          ScaleTransition(
            scale: provider.isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: GestureDetector(
              onTap: provider.isProcessing ? null : (provider.isRecording ? _stopRecording : _startRecording),
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: provider.isRecording ? [Colors.red.shade400, Colors.red.shade600] : [Colors.teal.shade400, Colors.teal.shade600]),
                  boxShadow: [BoxShadow(color: (provider.isRecording ? Colors.red : Colors.teal).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Icon(provider.isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.orange), onPressed: provider.isRecording ? null : () { provider.clearResults(); provider.clearRecording(); _fadeController.reset(); }),
        ],
      ),
    );
  }

  Future<void> _startRecording() async => await context.read<AudioDetectionProvider>().startRecording();
  Future<void> _stopRecording() async => await context.read<AudioDetectionProvider>().stopRecording();
  
  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      await context.read<AudioDetectionProvider>().analyzeAudioFile(File(result.files.single.path!));
    }
  }

  void _showDetailsSheet(EmotionResult result) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
             Text("Emotion Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
             const SizedBox(height: 20),
             ...result.allEmotions.entries.map((e) => Padding(
               padding: const EdgeInsets.symmetric(vertical: 8),
               child: Row(children: [
                 Text(_getEmotionEmoji(e.key), style: const TextStyle(fontSize: 20)),
                 const SizedBox(width: 12),
                 Expanded(child: Text(e.key.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]))),
                 Text("${(e.value * 100).toStringAsFixed(1)}%", style: TextStyle(fontWeight: FontWeight.bold, color: _getEmotionColor(e.key))),
               ]),
             )),
             const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _getConversationalAdvice(BuildContext context) {
    if (!mounted) return;
    final provider = context.read<AudioDetectionProvider>();
    if (provider.lastResult == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AdviceDialog(
        emotionResult: provider.lastResult!,
        userSpeech: provider.liveTranscribedText,
      ),
    );
  }
  
  String _formatDuration(Duration d) => '${d.inMinutes.toString().padLeft(2,'0')}:${(d.inSeconds % 60).toString().padLeft(2,'0')}';

  Color _getEmotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return Colors.green;
      case 'sad': return Colors.blue;
      case 'angry': return Colors.red;
      default: return Colors.purple;
    }
  }

  String _getEmotionEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'happy': return '😊';
      case 'sad': return '😢';
      case 'angry': return '😠';
      default: return '😐';
    }
  }
}