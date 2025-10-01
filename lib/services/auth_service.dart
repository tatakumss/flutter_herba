import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'appwrite_service.dart';
import '../config/app_config.dart';

// User Model for Appwrite
class AppwriteUser {
  final String uid;
  final String email;
  final String? name;
  final bool emailVerification;

  AppwriteUser({
    required this.uid, 
    required this.email, 
    this.name,
    required this.emailVerification,
  });

  factory AppwriteUser.fromUser(User user) => AppwriteUser(
    uid: user.$id,
    email: user.email,
    name: user.name.isNotEmpty ? user.name : null,
    emailVerification: user.emailVerification,
  );

  // For compatibility with existing code
  String? get displayName => name;
  bool get isEmailVerified => emailVerification;
}

// Appwrite Authentication Service
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final StreamController<AppwriteUser?> _authStateController = StreamController<AppwriteUser?>.broadcast();
  AppwriteUser? _currentUser;

  // Get current user
  AppwriteUser? get currentUser => _currentUser;
  
  // Auth state stream
  Stream<AppwriteUser?> get authStateChanges => _authStateController.stream;
  
  // Initialize auth service
  Future<void> init() async {
    try {
      // Check if user is already logged in
      final user = await AppwriteService.account.get();
      _currentUser = AppwriteUser.fromUser(user);
      _authStateController.add(_currentUser);
    } catch (e) {
      // User not logged in
      _currentUser = null;
      _authStateController.add(null);
    }
  }
  
  // Sign in with email and password
  Future<AppwriteUser?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('🔐 Attempting login for: $email');
      
      await AppwriteService.account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      
      print('✅ Session created successfully');
      
      final user = await AppwriteService.account.get();
      _currentUser = AppwriteUser.fromUser(user);
      _authStateController.add(_currentUser);
      
      print('✅ User logged in: ${_currentUser!.email}');
      
      return _currentUser;
    } on AppwriteException catch (e) {
      print('❌ Login failed: ${e.code} - ${e.message}');
      throw _handleAppwriteException(e);
    } catch (e) {
      print('❌ Unexpected error: $e');
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password, {String? displayName}) async {
    try {
      await AppwriteService.account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: displayName ?? '',
      );
      
      return true;
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await AppwriteService.account.deleteSession(sessionId: 'current');
      _currentUser = null;
      _authStateController.add(null);
    } catch (e) {
      // Handle error silently for logout
      _currentUser = null;
      _authStateController.add(null);
    }
  }
  
  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await AppwriteService.account.createVerification(
        url: AppConfig.emailVerificationUrl,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to send verification email. Please try again.';
    }
  }
  
  // Complete email verification with token
  Future<void> completeEmailVerification(String userId, String secret) async {
    try {
      await AppwriteService.account.updateVerification(
        userId: userId,
        secret: secret,
      );
      
      // Refresh user data to get updated verification status
      final user = await AppwriteService.account.get();
      _currentUser = AppwriteUser.fromUser(user);
      _authStateController.add(_currentUser);
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to verify email. Please try again or request a new verification link.';
    }
  }
  
  // Check if current user's email is verified
  bool get isEmailVerified => _currentUser?.isEmailVerified ?? false;
  
  // Refresh user data (useful after verification)
  Future<void> refreshUser() async {
    try {
      final user = await AppwriteService.account.get();
      _currentUser = AppwriteUser.fromUser(user);
      _authStateController.add(_currentUser);
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Send password recovery email
  Future<void> sendPasswordRecovery(String email) async {
    try {
      // Using localhost for testing password recovery
      await AppwriteService.account.createRecovery(
        email: email,
        url: 'http://localhost:3000/reset-password', // Localhost URL for testing
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to send password recovery email. Please try again.';
    }
  }
  
  // Change password (requires current password)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await AppwriteService.account.updatePassword(
        password: newPassword,
        oldPassword: currentPassword,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    }
  }
  
  // Handle Appwrite exceptions
  String _handleAppwriteException(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Invalid email or password.';
      case 404:
        return 'No account found with this email address.';
      case 409:
        return 'The account already exists for that email.';
      case 400:
        if (e.message?.contains('password') == true) {
          return 'The password provided is too weak.';
        }
        if (e.message?.contains('email') == true) {
          return 'Please enter a valid email address.';
        }
        return 'Invalid request. Please check your input.';
      case 429:
        return 'Too many requests. Please wait a few minutes before trying again.';
      case 500:
        return 'Server error. Please try again.';
      case 503:
        return 'Service temporarily unavailable.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
  
  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
