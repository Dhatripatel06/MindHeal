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
  final Wav2Vec2EmotionService _emotionService = Wav2Vec2EmotionService();
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

  // Keep track of the last recorded file for analysis/playback
  File? _lastRecordingFile;
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
  bool get isInitialized => _isInitialized;

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
    await _emotionService.initialize();

    // Cancel previous subscriptions if they exist
    _audioDataSubscription?.cancel();
    _durationSubscription?.cancel();

    _audioDataSubscription = _audioService.audioDataStream.listen((data) {
      _audioData = data;
      notifyListeners();
    });
    _durationSubscription =
        _audioService.recordingDurationStream.listen((duration) {
      _recordingDuration = duration;
      notifyListeners();
    });
    _isInitialized = true;
    print("AudioDetectionProvider Initialized");
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

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _isProcessing = true; // Now we process
    _lastError = null;
    _recordingDuration = Duration.zero; // Reset duration
    notifyListeners();

    try {
      final audioFile = await _audioService.stopRecording();
      if (audioFile != null) {
        _hasRecording = true;
        _lastRecordingFile = audioFile;
        await _runAnalysisPipeline(audioFile); // Run the new pipeline
      } else {
        throw Exception("Failed to save recording.");
      }
    } catch (e) {
      _lastError = "Error stopping/processing: $e";
      print(_lastError);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
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
      // TODO: We need to get audio data for the waveform.
      // This is complex and requires reading/downsampling the file.
      // For now, we'll just show an empty waveform.
      _audioData = [];
      _lastRecordingFile = audioFile;
      await _runAnalysisPipeline(audioFile); // Run the new pipeline
    } catch (e) {
      _lastError = "Error analyzing file: $e";
      print(_lastError);
    } finally {
      _isProcessing = false;
      notifyListeners();
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

  /// Analyze the most recent recording if available.
  Future<void> analyzeLastRecording() async {
    if (_lastRecordingFile == null) {
      _lastError = 'No recording available to analyze.';
      notifyListeners();
      return;
    }

    _isProcessing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _runAnalysisPipeline(_lastRecordingFile!);
    } catch (e) {
      _lastError = 'Error analyzing last recording: $e';
    } finally {
      _isProcessing = false;
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

  // --- *** THE NEW ANALYSIS PIPELINE *** ---
  Future<void> _runAnalysisPipeline(File audioFile) async {
    try {
      // 1. Analyze Emotion from Audio (using new ONNX model)
      // This happens first and gives us the EmotionResult for the UI bars
      _lastResult = await _emotionService.analyzeAudio(audioFile);
      notifyListeners(); // Show emotion bars immediately

      final detectedEmotion = _lastResult?.emotion ?? 'neutral';

      // 2. Transcribe Audio to Text (STT)
      String userText =
          await _sttService.transcribeAudio(audioFile, currentLangCode);
      if (userText.isEmpty) {
        userText = "(User said nothing but felt $detectedEmotion)";
      }

      // 3. Translate Text to English (if needed)
      String englishText = await _translationService.translate(
        userText,
        from: currentLangCode,
        to: 'en',
      );

      // 4. Get Gemini "Friend" Response
      // We ask Gemini for the response in English to ensure quality
      String englishResponse = await _geminiService.getConversationalAdvice(
        userSpeech: englishText,
        detectedEmotion: detectedEmotion,
        language: 'English', // Always get English response from AI
      );

      // 5. Translate Response back to User's Language
      String finalResponse = await _translationService.translate(
        englishResponse,
        from: 'en',
        to: currentLangCode, // Translate to selected language
      );

      // 6. Set friendly response for UI and speak it
      _friendlyResponse = finalResponse;
      notifyListeners();
      await _ttsService.speak(finalResponse, currentLocaleId);
    } catch (e) {
      print("Error in analysis pipeline: $e");
      _lastError = "Error in analysis: $e";
      // Provide a fallback response (use public helper on the instance)
      _friendlyResponse = _geminiService.getFallbackAdvice(
        _lastResult?.emotion ?? 'neutral',
        _selectedLanguage,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    _ttsService.dispose();
    _durationSubscription?.cancel();
    _audioDataSubscription?.cancel();
    super.dispose();
  }
}
