import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Import Google Sign-In
import 'package:flutter/foundation.dart' show kIsWeb; // To check if running on web

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // Initialize GoogleSignIn

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get the current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Sign Up with Email and Password
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    try {
      // Remove placeholder
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Improve error feedback - could be shown to the user
      print('FirebaseAuthException during sign up: ${e.code} - ${e.message}');
      // Consider re-throwing a custom exception or returning an error code
      return null;
    } catch (e) {
      print('An unexpected error occurred during sign up: $e');
      return null;
    }
  }

  // Sign In with Email and Password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      // Remove placeholder
      UserCredential userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
       // Improve error feedback
      print('FirebaseAuthException during sign in: ${e.code} - ${e.message}');
      // Consider re-throwing a custom exception or returning an error code
      return null;
    } catch (e) {
      print('An unexpected error occurred during sign in: $e');
      return null;
    }
  }

  // Sign In with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user cancels the flow, googleUser will be null
      if (googleUser == null) {
        print('Google Sign-In cancelled by user.');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new Firebase credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      print('Google Sign-In Successful: ${userCredential.user?.displayName}');
      return userCredential;

    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException during Google sign in: ${e.code} - ${e.message}');
      await _googleSignIn.signOut(); // Sign out from Google if Firebase fails
      return null;
    } catch (e) {
      print('An unexpected error occurred during Google sign in: $e');
      await _googleSignIn.signOut(); // Sign out from Google on unexpected error
      return null;
    }
  }

  // Sign In with Apple
  Future<UserCredential?> signInWithApple() async {
    // Platform specific setup required (iOS/macOS only)
    // Requires sign_in_with_apple package
    print('Sign In with Apple - Not Implemented (Requires iOS/macOS setup)');
    // TODO: Implement Apple Sign-In logic here using sign_in_with_apple package
    return null;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      // Also sign out from Google if currently signed in with Google
      if (await _googleSignIn.isSignedIn()) {
         await _googleSignIn.signOut();
         print('Signed out from Google');
      }

      // TODO: Sign out from Apple if needed

      await _firebaseAuth.signOut();
      print('Signed out from Firebase');
    } catch (e) {
      print('Error signing out: $e');
    }
  }
} 