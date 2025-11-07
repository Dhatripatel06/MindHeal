// lib/features/mood_detection/presentation/providers/audio_detection_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
import 'package:mental_wellness_app/core/services/speech_transcription_service.dart';
import 'package:mental_wellness_app/core/services/translation_service.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/audio_processing_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';

class AudioDetectionProvider extends ChangeNotifier {
  // --- All Services ---
  final AudioProcessingService _audioService = AudioProcessingService();
  
  // --- FIX 1: Use the singleton instance ---
  final Wav2Vec2EmotionService _emotionService = Wav2Vec2EmotionService.instance;
  
  final SpeechTranscriptionService _sttService = SpeechTranscriptionService();
  final TranslationService _translationService = TranslationService();
  final GeminiAdviserService _geminiService = GeminiAdviserService();
  final TtsService _ttsService = TtsService();

  // --- State for UI ---
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isVoiceDetected = false; // Note: This is hard to detect accurately
  bool _hasRecording = false;
  EmotionResult? _lastResult;
  String? _friendlyResponse;
  String? _lastError;
  List<double> _audioData = [];
  Duration _recordingDuration = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _audioDataSubscription;

  // --- State for New Feature ---
  String _selectedLanguage = 'English'; // 'English', 'हिंदी', 'ગુજરાતી'

  // --- Getters for UI ---
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isVoiceDetected => _isVoiceDetected; // Placeholder
  bool get hasRecording => _hasRecording;
  EmotionResult? get lastResult => _lastResult;
  String? get friendlyResponse => _friendlyResponse;
  String? get lastError => _lastError;
  List<double> get audioData => _audioData;
  Duration get recordingDuration => _recordingDuration;
  String get selectedLanguage => _selectedLanguage;
  bool get isInitialized => _isInitialized; // Expose this

  // --- Language Mapping ---
  /// Gets the ISO 639-1 code for Whisper and Translator
  String get currentLangCode {
    switch (_selectedLanguage) {
      case 'हिंदी':
        return 'hi';
      case 'ગુજરાતી':
        return 'gu';
      default:
        return 'en';
    }
  }

  /// Gets the BCP 47 code for Flutter TTS
  String get currentLocaleId {
    switch (_selectedLanguage) {
      case 'हिंदी':
        return 'hi-IN';
      case 'ગુજરાતી':
        return 'gu-IN';
      default:
        return 'en-US';
    }
  }

  // --- Initialization ---
  Future<void> initialize() async {
    if (_isInitialized) return;

    // --- FIX 2: Do NOT initialize the singleton service here ---
    // This is now done in main.dart
    // await _emotionService.initialize(); 

    // Cancel previous subscriptions if they exist
    _audioDataSubscription?.cancel();
    _durationSubscription?.cancel();

    _audioDataSubscription = _audioService.audioDataStream.listen((data) {
      _audioData = data;
      if (mounted) notifyListeners();
    });
    _durationSubscription =
        _audioService.recordingDurationStream.listen((duration) {
      _recordingDuration = duration;
      if (mounted) notifyListeners();
    });
    _isInitialized = true;
    print("AudioDetectionProvider Initialized.");
  }

  // --- Language Selection ---
  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  // --- UI Control Methods ---
  Future<void> startRecording() async {
    if (_isRecording) return;
    clearResults();
    clearRecording(); // Also clears audio data
    _isRecording = true;
    _isProcessing = false;
    _lastError = null;
    notifyListeners();
    try {
      await _audioService.startRecording();
    } catch (e) {
      _lastError = e.toString();
      _isRecording = false;
      notifyListeners();
    }
  }

  // Updated to return File? for combined_detection_provider
  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _isProcessing = true; // Now we process
    _lastError = null;
    _recordingDuration = Duration.zero; // Reset duration
    notifyListeners();

    File? audioFile;
    try {
      audioFile = await _audioService.stopRecording();
      if (audioFile != null) {
        _hasRecording = true;
        await _runAnalysisPipeline(audioFile); // Run the new pipeline
      } else {
        throw Exception("Failed to save recording.");
      }
    } catch (e) {
      _lastError = "Error stopping/processing: $e";
      print(_lastError);
    } finally {
      if (mounted) {
        _isProcessing = false;
        notifyListeners();
      }
    }
    return audioFile; // Return the file
  }

  Future<void> analyzeAudioFile(File audioFile) async {
    clearResults();
    clearRecording();
    _isRecording = false;
    _isProcessing = true;
    _hasRecording = true; // We have a file
    _lastError = null;
    notifyListeners();

    try {
      _audioData = []; // Waveform for uploaded files is not implemented
      await _runAnalysisPipeline(audioFile); // Run the new pipeline
    } catch (e) {
      _lastError = "Error analyzing file: $e";
      print(_lastError);
    } finally {
      if (mounted) {
        _isProcessing = false;
        notifyListeners();
      }
    }
  }

  Future<void> playLastRecording() async {
    try {
      await _audioService.playLastRecording();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  void clearRecording() {
    _audioService.clearRecording();
    _hasRecording = false;
    _audioData = [];
    _recordingDuration = Duration.zero;
    clearResults(); // Clearing recording should also clear results
  }

  void clearResults() {
    _lastResult = null;
    _friendlyResponse = null;
    _lastError = null;
    notifyListeners();
  }

  // --- *** THE ANALYSIS PIPELINE *** ---
  Future<void> _runAnalysisPipeline(File audioFile) async {
    try {
      // 1. Analyze Emotion from Audio (Local ONNX)
      _lastResult = await _emotionService.analyzeAudio(audioFile);
      if (mounted) notifyListeners(); // Show emotion bars immediately

      final detectedEmotion = _lastResult?.emotion ?? 'neutral';

      // 2. Transcribe Audio to Text (Local Whisper)
      String userText =
          await _sttService.transcribeAudio(audioFile, currentLangCode);
      if (userText.isEmpty) {
        userText = "(User said nothing but felt $detectedEmotion)";
      }

      // 3. Translate Text to English (Local ML Kit)
      String englishText = await _translationService.translate(
        userText,
        from: currentLangCode,
        to: 'en',
      );

      // 4. Get Gemini "Friend" Response (API Call)
      String englishResponse = await _geminiService.getConversationalAdvice(
        userSpeech: englishText,
        detectedEmotion: detectedEmotion,
        language: 'English',
      );

      // 5. Translate Response back to User's Language (Local ML Kit)
      String finalResponse = await _translationService.translate(
        englishResponse,
        from: 'en',
        to: currentLangCode,
      );

      // 6. Set friendly response for UI and speak it
      _friendlyResponse = finalResponse;
      if (mounted) notifyListeners();
      await _ttsService.speak(finalResponse, currentLocaleId);
    } catch (e) {
      print("Error in analysis pipeline: $e");
      _lastError = "Error in analysis: $e";
      // Provide a fallback response using the public method
      _friendlyResponse = _geminiService.getFallbackAdvice(
        _lastResult?.emotion ?? 'neutral',
        _selectedLanguage,
      );
      if (mounted) notifyListeners();
    }
  }

  // --- Check if provider is still mounted before notifying listeners ---
  bool _mounted = true;
  bool get mounted => _mounted;

  @override
  void dispose() {
    _audioService.dispose();
    
    // --- FIX 3: DO NOT DISPOSE THE TTS SERVICE ---
    // This prevents the crash when navigating to other pages.
    // _ttsService.dispose(); 
    
    _durationSubscription?.cancel();
    _audioDataSubscription?.cancel();
    _mounted = false; // Set mounted to false
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (mounted) {
      super.notifyListeners();
    }
  }
}