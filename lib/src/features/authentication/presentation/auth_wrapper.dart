import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../services/auth_service.dart';
import 'login_screen.dart';
// Import actual HomeScreen
import '../../home/presentation/home_screen.dart';

// Simple Wrapper to decide which screen to show based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = context.watch<User?>();

    if (firebaseUser != null) {
      // Show the real HomeScreen
      return const HomeScreen();
    } else {
      // Show LoginScreen if logged out
      return const LoginScreen();
    }
  }
} 