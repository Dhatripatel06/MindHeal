import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class GoogleSignInTest extends StatefulWidget {
  @override
  _GoogleSignInTestState createState() => _GoogleSignInTestState();
}

class _GoogleSignInTestState extends State<GoogleSignInTest> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Use the web client ID from your Firebase config
    clientId:
        '934484241138-klno99cg01iiildql4lfkpc76qh2bjqj.apps.googleusercontent.com',
  );

  String _status = 'Not signed in';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      setState(() {
        _isInitialized = true;
        _status = 'Firebase initialized. Ready to sign in.';
      });
    } catch (e) {
      setState(() {
        _status = 'Firebase initialization failed: $e';
      });
    }
  }

  Future<void> _handleSignIn() async {
    if (!_isInitialized) {
      setState(() => _status = 'Firebase not initialized yet');
      return;
    }

    try {
      setState(() => _status = 'Signing in...');

      // Clear any previous authentication state
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        setState(() => _status = 'Signed in as: ${account.email}');
      } else {
        setState(() => _status = 'Sign in cancelled');
      }
    } catch (error) {
      setState(() => _status = 'Error: $error');
      print('Google Sign-In Error: $error');
    }
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    setState(() => _status = 'Signed out');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Google Sign-In Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSignIn,
              child: Text('Sign In with Google'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _handleSignOut,
              child: Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
