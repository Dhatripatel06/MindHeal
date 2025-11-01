// lib/features/mood_detection/presentation/providers/conversational_friend_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mental_wellness_app/core/services/gemini_adviser_service.dart';
import 'package:mental_wellness_app/core/services/speech_to_text_service.dart';
import 'package:mental_wellness_app/core/services/translation_service.dart';
import 'package:mental_wellness_app/core/services/tts_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/audio_processing_service.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';

// A simple model for a chat message
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ConversationalFriendProvider extends ChangeNotifier {
  // --- All Services ---
  final AudioProcessingService _audioService = AudioProcessingService();
  final SpeechToTextService _sttService = SpeechToTextService();
  final TranslationService _translationService = TranslationService();
  final Wav2Vec2EmotionService _emotionService = Wav2Vec2EmotionService();
  final GeminiAdviserService _geminiService = GeminiAdviserService();
  final TtsService _ttsService = TtsService();

  // --- State ---
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isProcessing = false;
  String _selectedLanguage = 'English'; // 'English', 'हिंदी', 'ગુજરાતી'
  List<ChatMessage> _messages = [];

  // --- Getters ---
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  String get selectedLanguage => _selectedLanguage;
  List<ChatMessage> get messages => _messages;

  // --- Language Mapping ---
  String get _currentLocaleId {
    switch (_selectedLanguage) {
      case 'हिंदी':
        return 'hi-IN';
      case 'ગુજરાતી':
        return 'gu-IN';
      default:
        return 'en-US';
    }
  }

  String get _currentLangCode {
    switch (_selectedLanguage) {
      case 'हिंदी':
        return 'hi';
      case 'ગુજરાતી':
        return 'gu';
      default:
        return 'en';
    }
  }

  ConversationalFriendProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _sttService.initialize();
    await _emotionService.initialize();
    _ttsService.onStateChanged = (state) {
      if (state == TtsState.stopped) {
        _isProcessing = false;
        notifyListeners();
      }
    };
    _isInitialized = true;
    _addMessage("Hello! Tap the microphone and let's talk.", isUser: false);
  }

  void _addMessage(String text, {required bool isUser}) {
    _messages.insert(0, ChatMessage(text: text, isUser: isUser));
    notifyListeners();
  }

  void setLanguage(String language) {
    _selectedLanguage = language;
    notifyListeners();
  }

  // --- Main Control Function ---
  Future<void> toggleListening() async {
    if (!_isInitialized) return;

    if (_isListening) {
      // --- STOP LISTENING ---
      _isListening = false;
      notifyListeners();
      
      await _sttService.stopListening();
      final audioFile = await _audioService.stopRecording(); // This gives us the audio
      final userText = _sttService.lastWords;

      if (userText.isEmpty || audioFile == null) {
        _isProcessing = false;
        notifyListeners();
        return;
      }
      
      // Add user's message to UI
      _addMessage(userText, isUser: true);
      
      // Start processing pipeline
      _isProcessing = true;
      notifyListeners();
      await _processUserTurn(userText, audioFile);

    } else {
      // --- START LISTENING ---
      await _audioService.startRecording(
        // CRITICAL: Record at 16kHz for Wav2Vec2
        sampleRate: 16000,
        encoder: AudioEncoder.pcm16bits, // Use PCM for raw data
      );
      await _sttService.startListening(_currentLocaleId);
      _isListening = true;
      notifyListeners();
    }
  }

  Future<void> _processUserTurn(String userText, File audioFile) async {
    try {
      // 1. Translate user text to English (if needed)
      String englishText = userText;
      if (_currentLangCode != 'en') {
        englishText = await _translationService.translate(userText, from: _currentLangCode, to: 'en');
      }

      // 2. Analyze emotion from audio
      // This service needs the raw 16kHz PCM file
      String emotion = await _emotionService.analyzeAudio(audioFile);

      // 3. Get Gemini response in English
      String englishResponse = await _geminiService.getConversationalAdvice(
        userSpeech: englishText,
        detectedEmotion: emotion,
        language: 'English', // Always ask Gemini for English
      );

      // 4. Translate response back to user's language (if needed)
      String finalResponse = englishResponse;
      if (_currentLangCode != 'en') {
        finalResponse = await _translationService.translate(englishResponse, from: 'en', to: _currentLangCode);
      }
      
      // 5. Add AI message and speak it
      _addMessage(finalResponse, isUser: false);
      await _ttsService.speak(finalResponse, _currentLocaleId);
      
      // Note: _isProcessing is set to false by the TTS completion handler

    } catch (e) {
      print("Error in processing turn: $e");
      _addMessage("I'm sorry, I had a little trouble understanding. Could you try again?", isUser: false);
      _isProcessing = false;
      notifyListeners();
    }
  }
}