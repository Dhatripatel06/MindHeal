// lib/features/mood_detection/presentation/providers/audio_detection_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
// --- FIX: Import the new service ---
import 'package:mental_wellness_app/core/services/live_speech_transcription_service.dart';
// --- FIX: DELETE this import ---
// import 'package:mental_wellness_app/core/services/speech_transcription_service.dart'; 
import 'package:mental_wellness_app/core/services/translation_service.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/audio_processing_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';

class AudioDetectionProvider extends ChangeNotifier {
  // --- All Services ---
  final AudioProcessingService _audioService = AudioProcessingService();
  final Wav2Vec2EmotionService _emotionService = Wav2Vec2EmotionService.instance;
  
  // --- FIX: Use the new service ---
  final LiveSpeechTranscriptionService _sttService = LiveSpeechTranscriptionService();
  
  final TranslationService _translationService = TranslationService();
  final GeminiAdviserService _geminiService = GeminiAdviserService();
  final TtsService _ttsService = TtsService();

  // --- State for UI ---
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isVoiceDetected = false;
  bool _hasRecording = false;
  EmotionResult? _lastResult;
  String? _friendlyResponse;
  String? _lastError;
  List<double> _audioData = [];
  Duration _recordingDuration = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _audioDataSubscription;

  // --- FIX: Add state for live text ---
  String _liveTranscribedText = "";

  String _selectedLanguage = 'English';

  // --- Getters for UI ---
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isVoiceDetected => _isVoiceDetected;
  bool get hasRecording => _hasRecording;
  EmotionResult? get lastResult => _lastResult;
  String? get friendlyResponse => _friendlyResponse;
  String? get lastError => _lastError;
  List<double> get audioData => _audioData;
  Duration get recordingDuration => _recordingDuration;
  String get selectedLanguage => _selectedLanguage;
  bool get isInitialized => _isInitialized;

  // --- FIX: Getter for live text ---
  String get liveTranscribedText => _liveTranscribedText;


  // --- Language Mapping ---
  /// Gets the ISO 639-1 code for Translator
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

  /// Gets the BCP 47 code for Flutter TTS AND speech_to_text
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

    // --- FIX: Initialize the new STT service ---
    await _sttService.initialize();
    // Listen to updates from the STT service
    _sttService.addListener(() {
      _liveTranscribedText = _sttService.liveWords;
      if (_isRecording && !_sttService.isListening) {
        // STT stopped prematurely (e.g., silence), so we stop everything
        if (mounted) {
           print("STT stopped, stopping recording...");
           stopRecording(); 
        }
      } else {
        if (mounted) notifyListeners();
      }
    });

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
    clearRecording();
    _isRecording = true;
    _isProcessing = false;
    _lastError = null;
    _liveTranscribedText = ""; // Clear live text
    notifyListeners();
    try {
      // --- FIX: Start both services ---
      await _audioService.startRecording();
      await _sttService.startListening(currentLocaleId);
    } catch (e) {
      _lastError = e.toString();
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _isProcessing = true;
    _lastError = null;
    _recordingDuration = Duration.zero;
    notifyListeners();

    File? audioFile;
    try {
      // --- FIX: Stop both services and get results ---
      audioFile = await _audioService.stopRecording();
      await _sttService.stopListening();
      final String transcribedText = _sttService.finalText;
      
      _liveTranscribedText = transcribedText; // Show final text

      if (audioFile != null) {
        _hasRecording = true;
        // --- FIX: Pass the text to the pipeline ---
        await _runAnalysisPipeline(audioFile, transcribedText);
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
    return audioFile;
  }

  Future<void> analyzeAudioFile(File audioFile) async {
    clearResults();
    clearRecording();
    _isRecording = false;
    _isProcessing = true;
    _hasRecording = true;
    _lastError = null;
    _liveTranscribedText = "(Cannot transcribe an uploaded file)"; // Set message
    notifyListeners();

    try {
      _audioData = [];
      // --- FIX: We can't transcribe a file, so just run emotion analysis
      // And use a placeholder text
      await _runAnalysisPipeline(audioFile, "(Uploaded audio file)");
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
    _liveTranscribedText = ""; // Clear text
    clearResults();
  }

  void clearResults() {
    _lastResult = null;
    _friendlyResponse = null;
    _lastError = null;
    notifyListeners();
  }

  // --- *** THE ANALYSIS PIPELINE *** ---
  // --- FIX: Take userText as an argument ---
  Future<void> _runAnalysisPipeline(File audioFile, String userText) async {
    try {
      // 1. Analyze Emotion from Audio (Local ONNX)
      _lastResult = await _emotionService.analyzeAudio(audioFile);
      if (mounted) notifyListeners();

      final detectedEmotion = _lastResult?.emotion ?? 'neutral';

      // 2. Transcribe Audio to Text (REMOVED - we now get it as an argument)
      if (userText.isEmpty || userText == "(Uploaded audio file)") {
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
      _friendlyResponse = _geminiService.getFallbackAdvice(
        _lastResult?.emotion ?? 'neutral',
        _selectedLanguage,
      );
      if (mounted) notifyListeners();
    }
  }

  bool _mounted = true;
  bool get mounted => _mounted;

  @override
  void dispose() {
    _audioService.dispose();
    _sttService.dispose(); // --- FIX: Dispose the new service ---
    _durationSubscription?.cancel();
    _audioDataSubscription?.cancel();
    _mounted = false;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (mounted) {
      super.notifyListeners();
    }
  }
}