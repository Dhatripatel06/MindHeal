// lib/core/services/speech_to_text_service.dart
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechToTextService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _lastWords = '';
  String _currentLocaleId = 'en-US';

  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  Future<bool> initialize() async {
    _isInitialized = await _speechToText.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) => _handleStatusChange(status),
    );
    return _isInitialized;
  }

  void _handleStatusChange(String status) {
    if (status == SpeechToText.listeningStatus) {
      _isListening = true;
    } else if (status == SpeechToText.notListeningStatus) {
      _isListening = false;
    }
  }

  Future<void> startListening(String localeId) async {
    if (!_isInitialized) await initialize();
    if (_isListening) await stopListening(); // Stop any previous session

    _currentLocaleId = localeId;
    _lastWords = '';
    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        _lastWords = result.recognizedWords;
      },
      localeId: _currentLocaleId,
      listenFor: const Duration(minutes: 1), // Listen for up to a minute
      pauseFor: const Duration(seconds: 5), // Auto-stop after 5s of silence
    );
    _isListening = true;
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    _isListening = false;
  }
}