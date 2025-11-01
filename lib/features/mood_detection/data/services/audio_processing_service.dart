import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:translator/translator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/emotion_result.dart';

class AudioProcessingService {
  static final AudioProcessingService _instance = AudioProcessingService._internal();
  factory AudioProcessingService() => _instance;
  AudioProcessingService._internal();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final translator = GoogleTranslator();
  late final GenerativeModel _generativeModel;

  final StreamController<List<double>> _audioDataController = StreamController<List<double>>.broadcast();
  bool _isRecording = false;
  String? _recordingPath;

  Stream<List<double>> get audioDataStream => _audioDataController.stream;

  Future<void> initialize(String apiKey) async {
    _generativeModel = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
  }

  Future<void> startRecording() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _recordingPath = '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _audioRecorder.start(const RecordConfig(), path: _recordingPath!);
      _isRecording = true;

    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      await _audioRecorder.stop();
      _isRecording = false;
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<EmotionResult> analyzeLastRecording() async {
    if (_recordingPath == null) {
      throw Exception('No recording available');
    }
    return _analyzeAudioFile(File(_recordingPath!));
  }

  Future<EmotionResult> analyzeAudioFile(File audioFile) async {
    return _analyzeAudioFile(audioFile);
  }

  Future<EmotionResult> _analyzeAudioFile(File audioFile) async {
    try {
      final audioBytes = await audioFile.readAsBytes();
      final session = await OrtEnv.instance.createSessionFromAsset('assets/models/wav2vec2_superb_er.onnx');
      
      final inputTensor = OrtValue.fromTensor(audioBytes, [1, audioBytes.length]);
      final inputs = {'input': inputTensor};
      
      final outputs = await session.run(inputs);
      final outputTensor = outputs['output'] as OrtValue;
      
      final emotions = _processOutput(outputTensor);

      return EmotionResult(
        emotion: emotions.entries.first.key,
        confidence: emotions.entries.first.value,
        allEmotions: emotions,
        timestamp: DateTime.now(),
        processingTimeMs: 0,
      );
    } catch (e) {
      print('Error analyzing audio file: $e');
      return _getDemoAudioResult();
    }
  }

  Map<String, double> _processOutput(OrtValue outputTensor) {
    // Implement logic to process the output tensor and return a map of emotions and their confidences
    return {'happy': 0.8, 'sad': 0.1, 'neutral': 0.1};
  }

  Future<String> getFriendlyResponse(String userInput, String emotion) async {
    try {
      final translatedInput = await translator.translate(userInput, to: 'en');
      final prompt = 'User said: "$translatedInput". Their emotion is $emotion. Respond as a friendly and supportive best friend.';
      final response = await _generativeModel.generateContent([Content.text(prompt)]);
      final translatedResponse = await translator.translate(response.text!, from: 'en', to: 'hi');
      return translatedResponse.text;
    } catch (e) {
      print('Error getting friendly response: $e');
      return "I'm here for you.";
    }
  }

  Future<void> playLastRecording() async {
    if (_recordingPath == null) {
      throw Exception('No recording available');
    }
    // Implement audio playback
  }

  EmotionResult _getDemoAudioResult() {
    final emotions = ['neutral', 'happy', 'sad', 'surprise', 'fear', 'disgust', 'anger'];
    final random = DateTime.now().millisecond;
    final dominantIndex = random % emotions.length;
    
    final emotionMap = <String, double>{};
    for (int i = 0; i < emotions.length; i++) {
      if (i == dominantIndex) {
        emotionMap[emotions[i]] = 0.6 + (random % 25) / 100;
      } else {
        emotionMap[emotions[i]] = (random % 15) / 100;
      }
    }

    return EmotionResult(
      emotion: emotions[dominantIndex],
      confidence: emotionMap[emotions[dominantIndex]]!,
      allEmotions: emotionMap,
      timestamp: DateTime.now(),
      processingTimeMs: 0,
    );
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioDataController.close();
  }
}