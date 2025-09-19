import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/main_screen.dart';
import '../screens/auth/login_screen.dart';

// Authentication Wrapper to handle auth state
class AuthWrapper extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return MainScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
