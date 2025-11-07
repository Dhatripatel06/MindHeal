import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mental_wellness_app/features/mood_detection/data/services/wav2vec2_emotion_service.dart';
import 'package:mental_wellness_app/features/mood_detection/onnx_emotion_detection/data/services/onnx_emotion_service.dart';
import 'app/app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🔥 Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // This will now initialize your AI models
  await initializeServices();

  runApp(const MentalWellnessApp());
}

Future<void> initializeServices() async {
  // Add initializations here
  
  // Initialize Image Emotion Service (Singleton)
  print("🚀 Initializing OnnxEmotionService...");
  await OnnxEmotionService.instance.initialize();
  print("✅ OnnxEmotionService Initialized.");

  // Initialize Audio Emotion Service (Singleton)
  print("🚀 Initializing Wav2Vec2EmotionService...");
  await Wav2Vec2EmotionService.instance.initialize();
  print("✅ Wav2Vec2EmotionService Initialized.");

  // Other services like TtsService, TranslationService, etc.
  // could also be initialized here if they are singletons.
}