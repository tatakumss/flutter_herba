import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/auth/email_verification_screen.dart';
import '../config/app_config.dart';

class VerificationUrlHandler {
  static final VerificationUrlHandler _instance = VerificationUrlHandler._internal();
  factory VerificationUrlHandler() => _instance;
  VerificationUrlHandler._internal();

  static BuildContext? _context;

  // Initialize the URL handler with the app context
  static void initialize(BuildContext context) {
    _context = context;
  }

  // Handle incoming verification URLs
  static Future<bool> handleVerificationUrl(String url) async {
    if (_context == null) return false;

    try {
      final uri = Uri.parse(url);
      
      // Handle email verification URLs
      if (uri.host == 'pediaherb.app' && uri.path == '/verify') {
        final userId = uri.queryParameters['userId'];
        final secret = uri.queryParameters['secret'];
        
        if (userId != null && secret != null) {
          Navigator.of(_context!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                userId: userId,
                secret: secret,
              ),
            ),
            (route) => false,
          );
          return true;
        }
      }
      
      // Handle app scheme URLs (pediaherb://verify)
      if (uri.scheme == 'pediaherb' && uri.host == 'verify') {
        final userId = uri.queryParameters['userId'];
        final secret = uri.queryParameters['secret'];
        
        if (userId != null && secret != null) {
          Navigator.of(_context!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                userId: userId,
                secret: secret,
              ),
            ),
            (route) => false,
          );
          return true;
        }
      }
    } catch (e) {
      print('Error handling verification URL: $e');
    }

    return false;
  }

  // Create a verification URL with parameters (for testing)
  static String createVerificationUrl(String userId, String secret) {
    return '${AppConfig.emailVerificationUrl}?userId=$userId&secret=$secret';
  }

  // Create app scheme URL for verification (for testing)
  static String createAppSchemeVerificationUrl(String userId, String secret) {
    return 'pediaherb://verify?userId=$userId&secret=$secret';
  }
}
