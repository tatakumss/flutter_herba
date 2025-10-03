import 'dart:async';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'appwrite_service.dart';

// User Model for Appwrite
class AppwriteUser {
  final String uid;
  final String email;
  final String? name;

  AppwriteUser({
    required this.uid, 
    required this.email, 
    this.name,
  });

  factory AppwriteUser.fromUser(User user) => AppwriteUser(
    uid: user.$id,
    email: user.email,
    name: user.name.isNotEmpty ? user.name : null,
  );

  // For compatibility with existing code
  String? get displayName => name;
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
  
  // Refresh user data
  Future<void> refreshUser() async {
    try {
      final user = await AppwriteService.account.get();
      _currentUser = AppwriteUser.fromUser(user);
      _authStateController.add(_currentUser);
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Test network connectivity to Appwrite
  Future<bool> testConnectivity() async {
    try {
      print('Testing connectivity to Appwrite...'); // Debug log
      
      // Try to make a simple request to test connectivity
      await AppwriteService.account.get();
      return true; // Connected (user is logged in)
    } catch (e) {
      if (e is AppwriteException && e.code == 401) {
        return true; // Connected but not logged in (this is expected)
      }
      
      print('Connectivity test failed: $e'); // Debug log
      return false; // Network issue
    }
  }

  // Send password recovery email
  Future<void> sendPasswordRecovery(String email) async {
    try {
      // Validate email format before sending
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw 'Please enter a valid email address.';
      }

      print('Sending password recovery for: $email'); // Debug log
      print('Using endpoint: ${AppwriteService.client.endPoint}'); // Debug log
      print('Using project: ${AppwriteService.client.config['project']}'); // Debug log
      
      // Test connectivity first
      bool isConnected = await testConnectivity();
      if (!isConnected) {
        throw 'Unable to connect to server. Please check your internet connection and try again.';
      }
      
      // Add retry logic for network issues
      int retryCount = 0;
      const maxRetries = 3;
      
      while (retryCount < maxRetries) {
        try {
          await AppwriteService.account.createRecovery(
            email: email,
            url: 'https://tatakumss.github.io/appwrite-reset-and-verify/password-reset.html',
          );
          
          print('Password recovery email sent successfully'); // Debug log
          return; // Success, exit retry loop
          
        } catch (e) {
          retryCount++;
          print('Attempt $retryCount failed: $e'); // Debug log
          
          if (retryCount >= maxRetries) {
            rethrow; // Re-throw the error after max retries
          }
          
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
      
    } on AppwriteException catch (e) {
      print('Appwrite error: ${e.code} - ${e.message} - ${e.type}'); // Debug log
      throw _handleAppwriteException(e);
    } catch (e) {
      print('General error: $e'); // Debug log
      
      // Handle specific network errors
      String errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('failed to fetch') || 
          errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout')) {
        throw 'Network error. Please check your internet connection and try again.';
      } else if (errorMessage.contains('cors') || errorMessage.contains('cross-origin')) {
        throw 'Connection blocked. Please try again or contact support.';
      } else {
        throw 'Failed to send password recovery email. Please check your internet connection and try again.';
      }
    }
  }
  
  // Complete password recovery with verification code
  Future<void> completePasswordRecovery(String userId, String secret, String newPassword) async {
    try {
      await AppwriteService.account.updateRecovery(
        userId: userId,
        secret: secret,
        password: newPassword,
      );
    } on AppwriteException catch (e) {
      throw _handleAppwriteException(e);
    } catch (e) {
      throw 'Failed to reset password. Please try again.';
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
        if (e.message?.contains('URL') == true || e.message?.contains('url') == true) {
          return 'Configuration error. Please contact support.';
        }
        if (e.message?.contains('User') == true && e.message?.contains('not found') == true) {
          return 'No account found with this email address.';
        }
        // Return the actual error message for debugging
        return 'Error: ${e.message ?? "Invalid request. Please check your input."}';
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
