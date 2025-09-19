import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app/app.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase - CRITICAL for authentication
  await Firebase.initializeApp();
  
  // Set preferred orientations (optional)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize any required services here
  await initializeServices();
  
  runApp(const MentalWellnessApp());
}

Future<void> initializeServices() async {
  // Initialize local database
  // await DatabaseService.initialize();
  
  // Initialize notification services
  // await NotificationService.initialize();
  
  // Initialize any ML models
  // await MLModelService.initialize();
  
  // Initialize biofeedback services
  // await BiofeedbackService.initialize();
  
  // Add any other service initializations here
}
