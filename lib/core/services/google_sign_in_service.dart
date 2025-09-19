import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Get current Google user
  static GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  // Check if user is signed in with Google
  static bool get isSignedIn => _googleSignIn.currentUser != null;

  // Sign in with Google
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      throw Exception('Google Sign-In failed: ${e.toString()}');
    }
  }

  // Sign out from Google
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      throw Exception('Google Sign-Out failed: ${e.toString()}');
    }
  }

  // Disconnect Google account
  static Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      throw Exception('Google disconnect failed: ${e.toString()}');
    }
  }

  // Get Google authentication for Firebase
  static Future<OAuthCredential> getFirebaseCredential(
    GoogleSignInAccount googleUser,
  ) async {
    try {
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
    } catch (e) {
      throw Exception('Failed to get Firebase credential: ${e.toString()}');
    }
  }

  // Sign in silently (auto sign-in)
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      return null;
    }
  }
}
