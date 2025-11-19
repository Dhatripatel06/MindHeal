import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
import 'package:mental_wellness_app/core/services/live_speech_transcription_service.dart';
import 'package:mental_wellness_app/core/services/translation_service.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/models/emotion_result.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/audio_processing_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';

class AudioDetectionProvider extends ChangeNotifier {
  final AudioProcessingService _audioService = AudioProcessingService();
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

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get hasRecording => _hasRecording;
  EmotionResult? get lastResult => _lastResult;
  String? get friendlyResponse => _friendlyResponse;
  String? get lastError => _lastError;
  List<double> get audioData => _audioData;
  Duration get recordingDuration => _recordingDuration;
  String get selectedLanguage => _selectedLanguage;
  bool get isInitialized => _isInitialized;
  String get liveTranscribedText => _liveTranscribedText;
  String? get audioFilePath => _lastRecordedFilePath;

  String get currentLangCode => _selectedLanguage == 'हिंदी' ? 'hi' : (_selectedLanguage == 'ગુજરાતી' ? 'gu' : 'en');
  String get currentLocaleId => _selectedLanguage == 'हिंदी' ? 'hi-IN' : (_selectedLanguage == 'ગુજરાતી' ? 'gu-IN' : 'en-US');

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _sttService.initialize();
    _sttService.addListener(() {
      _liveTranscribedText = _sttService.liveWords;
      if (mounted) notifyListeners();
    });

    _audioService.audioDataStream.listen((data) {
      _audioData = data;
      if (mounted) notifyListeners();
    });
    
    _audioService.recordingDurationStream.listen((duration) {
      _recordingDuration = duration;
      if (mounted) notifyListeners();
    });
    
    _isInitialized = true;
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    clearResults();
    clearRecording();
    _isRecording = true;
    _isProcessing = false;
    _lastError = null;
    _liveTranscribedText = "";
    notifyListeners();
    
    try {
      await _audioService.startRecording();
      try { await _sttService.startListening(currentLocaleId); } catch (e) { print("STT Warn: $e"); }
    } catch (e) {
      _lastError = "Could not start recording: $e";
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<File?> stopRecording() async {
    if (!_isRecording) return null;
    _isRecording = false;
    _isProcessing = true;
    notifyListeners();

    File? audioFile;
    try {
      audioFile = await _audioService.stopRecording();
      await _sttService.stopListening();
      
      if (audioFile != null) {
        _hasRecording = true;
        _lastRecordedFilePath = audioFile.path;
        
        String text = _sttService.finalText;
        if (text.isEmpty) text = _liveTranscribedText;
        if (text.isEmpty) text = "(No clear speech detected)";
        _liveTranscribedText = text;
        
        await _runAnalysisPipeline(audioFile, text);
      }
    } catch (e) {
      _lastError = "Error: $e";
    } finally {
      if (mounted) { _isProcessing = false; notifyListeners(); }
    }
    return audioFile;
  }

  Future<void> analyzeAudioFile(File audioFile) async {
    clearResults();
    clearRecording();
    _isRecording = false;
    _isProcessing = true;
    _hasRecording = true;
    _lastRecordedFilePath = audioFile.path;
    _liveTranscribedText = "(Uploaded Audio File)";
    notifyListeners();

    try {
      _audioData = [];
      await _runAnalysisPipeline(audioFile, "(User uploaded an audio file)");
    } catch (e) {
      _lastError = "Analysis failed: $e";
    } finally {
      if (mounted) { _isProcessing = false; notifyListeners(); }
    }
  }

  Future<void> _runAnalysisPipeline(File audioFile, String userText) async {
    try {
      // 1. Tone Analysis
      _lastResult = await _emotionService.analyzeAudio(audioFile);
      if (mounted) notifyListeners();
      
      final emotion = _lastResult?.emotion ?? 'neutral';

      // 2. Translate Input
      String textForAI = userText;
      if (currentLangCode != 'en' && !userText.startsWith("(")) {
        textForAI = await _translationService.translate(userText, from: currentLangCode, to: 'en');
      }

      // 3. Get Friend Advice
      String englishAdvice = await _geminiService.getConversationalAdvice(
        userSpeech: textForAI,
        detectedEmotion: emotion,
        language: 'English',
      );

      // 4. Translate Output
      String finalAdvice = englishAdvice;
      if (currentLangCode != 'en') {
        finalAdvice = await _translationService.translate(englishAdvice, from: 'en', to: currentLangCode);
      }

      _friendlyResponse = finalAdvice;
      if (mounted) notifyListeners();

      // 5. Speak
      await _ttsService.speak(finalAdvice, currentLocaleId);

    } catch (e) {
      print("Pipeline Error: $e");
      _lastError = "Friend feature unavailable: $e";
      if (mounted) notifyListeners();
    }
  }

  Future<void> playLastRecording() async {
    try { await _audioService.playLastRecording(); } catch (e) { _lastError = e.toString(); notifyListeners(); }
  }

  void clearRecording() {
    _audioService.clearRecording();
    _hasRecording = false;
    _lastRecordedFilePath = null;
    _audioData = [];
    _recordingDuration = Duration.zero;
    _liveTranscribedText = "";
    clearResults();
  }

  void clearResults() {
    _lastResult = null;
    _friendlyResponse = null;
    _lastError = null;
    notifyListeners();
  }

  bool _mounted = true;
  bool get mounted => _mounted;
  @override
  void dispose() {
    _audioService.dispose();
    _sttService.dispose();
    _mounted = false;
    super.dispose();
  }
  @override
  void notifyListeners() { if (mounted) super.notifyListeners(); }
}