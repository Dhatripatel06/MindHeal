import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

  // 1. Setup Global Error Handling (Replaces runZonedGuarded)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    print("🔴 Flutter Error: ${details.exception}");
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    print("🔴 Async Error: $error");
    return true;
  };

  try {
    await dotenv.load(fileName: ".env");
    await Firebase.initializeApp();

    // 2. Fix Firebase App Check (Prevents 403 Errors)
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    print("⚠️ Initialization Warning: $e");
  }

  // 3. Run App Immediately (Don't wait for AI models)
  runApp(const MentalWellnessApp());

  // 4. Initialize AI Models in Background (Prevents UI Freeze)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeBackgroundServices();
  });
}

Future<void> _initializeBackgroundServices() async {
  print("⏳ initializing AI Services in Background...");
  
  // Initialize independently so one failure doesn't stop the other
  OnnxEmotionService.instance.initialize().then((_) {
    print("✅ OnnxEmotionService Ready");
  }).catchError((e) => print("❌ Onnx Init Error: $e"));

  Wav2Vec2EmotionService.instance.initialize().then((_) {
    print("✅ Wav2Vec2EmotionService Ready");
  }).catchError((e) => print("❌ Wav2Vec2 Init Error: $e"));
}