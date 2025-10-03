// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import '../services/auth_service.dart';
import '../screens/main_screen.dart';
import '../screens/auth/login_screen.dart';

// Authentication Wrapper to handle auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.init();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppwriteUser?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Remove splash screen when auth state is determined
        FlutterNativeSplash.remove();
        
        if (snapshot.hasData) {
          return MainScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }
}
