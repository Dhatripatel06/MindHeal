import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/custom_splash_screen.dart';
import '../features/auth/presentation/widgets/auth_wrapper.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool _showCustomSplash = true;

  @override
  void initState() {
    super.initState();
    // Set status bar style for splash
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF483D8B),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _onSplashComplete() {
    setState(() {
      _showCustomSplash = false;
    });
    
    // Reset status bar style for main app
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showCustomSplash) {
      return CustomSplashScreen(
        onSplashComplete: _onSplashComplete,
      );
    }
    
    return const AuthWrapper();
  }
}