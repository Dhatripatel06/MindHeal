import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
import 'package:mental_wellness_app/core/services/live_speech_transcription_service.dart';
import 'package:mental_wellness_app/core/services/translation_service.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';

class AudioDetectionProvider extends ChangeNotifier {
  final Wav2Vec2EmotionService _emotionService = Wav2Vec2EmotionService.instance;
  final LiveSpeechTranscriptionService _sttService = LiveSpeechTranscriptionService();
  final TranslationService _translationService = TranslationService();
  final GeminiAdviserService _geminiService = GeminiAdviserService();
  final TtsService _ttsService = TtsService();

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _hasRecording = false;
  
  EmotionResult? _lastResult;
  String? _friendlyResponse;
  String? _lastError;
  List<double> _audioData = [];
  Duration _recordingDuration = Duration.zero;
  
  String _liveTranscribedText = "";
  String? _lastRecordedFilePath; 
  String _selectedLanguage = 'English';

  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  EmotionResult? get lastResult => _lastResult;
  String? get friendlyResponse => _friendlyResponse;
  List<double> get audioData => _audioData;
  Duration get recordingDuration => _recordingDuration;
  String get selectedLanguage => _selectedLanguage;
  String get liveTranscribedText => _liveTranscribedText;
  String? get audioFilePath => _lastRecordedFilePath;

  // Language Code mapping
  String get currentLangCode => _selectedLanguage == 'हिंदी' ? 'hi' : (_selectedLanguage == 'ગુજરાતી' ? 'gu' : 'en');
  String get currentLocaleId => _selectedLanguage == 'हिंदी' ? 'hi_IN' : (_selectedLanguage == 'ગુજરાતી' ? 'gu_IN' : 'en_US');

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Listeners
    _sttService.addListener(() {
      _liveTranscribedText = _sttService.liveWords;
      if (_mounted) notifyListeners();
    });
    
    _emotionService.audioDataStream.listen((data) {
      _audioData = data;
      if (_mounted) notifyListeners();
    });

    _emotionService.recordingDurationStream.listen((duration) {
      _recordingDuration = duration;
      if (_mounted) notifyListeners();
    });
    
    _isInitialized = true;
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    _clearState();
    _isRecording = true;
    _isProcessing = false;
    
    try {
      await _emotionService.startRecording();
      try { 
        await _sttService.startListening(currentLocaleId); 
      } catch (e) { 
        print("STT Warning: $e"); 
      }
      notifyListeners();
    } catch (e) {
      _lastError = "Could not start: $e";
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    _isProcessing = true;
    notifyListeners();

    try {
      // 1. Stop Audio
      File? audioFile = await _emotionService.stopRecording();
      await _sttService.stopListening();
      
      if (audioFile != null) {
        _hasRecording = true;
        _lastRecordedFilePath = audioFile.path;
        
        // 2. Get Text
        String userText = _sttService.finalText;
        if (userText.isEmpty) userText = _liveTranscribedText;
        if (userText.isEmpty) userText = "(No speech detected)";
        _liveTranscribedText = userText;

        // 3. Run Full Pipeline
        await _processFriendPipeline(audioFile, userText);
      }
    } catch (e) {
      _lastError = "Processing Error: $e";
    } finally {
      _isProcessing = false;
      if (_mounted) notifyListeners();
    }
  }

  // 🔥 THE REALITY LOGIC 🔥
  Future<void> _processFriendPipeline(File audioFile, String originalText) async {
    try {
      // A. Detect Tone (Emotion) from Audio
      _lastResult = await _emotionService.analyzeAudio(audioFile);
      String detectedEmotion = _lastResult?.emotion ?? 'neutral';
      
      // B. Translate Input to English (if needed)
      String englishText = originalText;
      if (currentLangCode != 'en') {
        englishText = await _translationService.translate(originalText, from: currentLangCode, to: 'en');
      }

      // C. Consult Gemini (The Friend)
      // It sees: "I am tired" (Text) + "SAD" (Tone)
      String englishAdvice = await _geminiService.getConversationalAdvice(
        userSpeech: englishText,
        detectedEmotion: detectedEmotion,
        language: 'English', // Get English response first for stability
      );

      // D. Translate Response back to User Language
      String finalResponse = englishAdvice;
      if (currentLangCode != 'en') {
        finalResponse = await _translationService.translate(englishAdvice, from: 'en', to: currentLangCode);
      }

      _friendlyResponse = finalResponse;
      
      // E. Speak it out
      await _ttsService.speak(finalResponse, currentLocaleId);

    } catch (e) {
      print("Pipeline Failed: $e");
      _lastError = "Could not analyze: $e";
    }
  }
  
  // Helper for file uploads
  Future<void> analyzeAudioFile(File audioFile) async {
    _clearState();
    _isProcessing = true;
    _hasRecording = true;
    _lastRecordedFilePath = audioFile.path;
    _liveTranscribedText = "(Uploaded File)";
    notifyListeners();

    await _processFriendPipeline(audioFile, "I uploaded an audio file.");
    _isProcessing = false;
    notifyListeners();
  }

  void _clearState() {
    _lastResult = null;
    _friendlyResponse = null;
    _lastError = null;
    _audioData = [];
    _recordingDuration = Duration.zero;
    _liveTranscribedText = "";
  }
  
  void clearResults() => _clearState();
  void clearRecording() => _clearState();

  bool _mounted = true;
  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
}