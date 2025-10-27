import 'package:flutter/material.dart';
import 'custom_splash_screen.dart';
import '../../app/app.dart';

/// Root widget that manages splash screen and main app flow
class AppRoot extends StatefulWidget {
  const AppRoot({Key? key}) : super(key: key);

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _showSplash = true;

  /// Called when splash screen completes its animations
  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Wellness',
      debugShowCheckedModeBanner: false,
      home: _showSplash
          ? CustomSplashScreen(
              onSplashComplete: _onSplashComplete,
            )
          : const MentalWellnessApp(),
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
    );
  }
}
