import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

// User Model for Firebase Auth
class AppwriteUser {
  final String uid;
  final String email;
  final String? name;
  final bool emailVerified;

  AppwriteUser({
    required this.uid, 
    required this.email, 
    this.name,
    this.emailVerified = false,
  });

  // Create from Firebase User
  factory AppwriteUser.fromFirebaseUser(User user) => AppwriteUser(
    uid: user.uid,
    email: user.email ?? '',
    name: user.displayName,
    emailVerified: user.emailVerified,
  );

  // For compatibility with existing code
  String? get displayName => name;
}

// Firebase Authentication Service
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StreamController<AppwriteUser?> _authStateController = StreamController<AppwriteUser?>.broadcast();
  AppwriteUser? _currentUser;
  bool _autoLoginEnabled = false;

  // Get current user
  AppwriteUser? get currentUser => _currentUser;
  
  // Auth state stream
  Stream<AppwriteUser?> get authStateChanges => _authStateController.stream;
  
  // Initialize auth service with Firebase
  Future<void> init({bool autoLogin = false}) async {
    _autoLoginEnabled = autoLogin;
    
    // Listen to Firebase auth state changes
    _auth.authStateChanges().listen((User? user) {
      // Only update auth state if auto-login is enabled
      if (_autoLoginEnabled) {
        if (user != null) {
          _currentUser = AppwriteUser.fromFirebaseUser(user);
        } else {
          _currentUser = null;
        }
        _authStateController.add(_currentUser);
      }
    });
    
    // Set initial user state - only auto-login if explicitly requested
    if (autoLogin) {
      final user = _auth.currentUser;
      if (user != null) {
        _currentUser = AppwriteUser.fromFirebaseUser(user);
      } else {
        _currentUser = null;
      }
    } else {
      // Force logout on app start to require explicit login
      await _auth.signOut();
      _currentUser = null;
    }
    _authStateController.add(_currentUser);
  }
  
  // Sign in with email and password (validates credentials only)
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (result.user != null) {
        // Immediately sign out to prevent automatic login
        await _auth.signOut();
        return true; // Credentials are valid
      }
      return false;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Actually log in the user (call this when you want to log them in)
  Future<AppwriteUser?> loginWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (result.user != null) {
        _currentUser = AppwriteUser.fromFirebaseUser(result.user!);
        _authStateController.add(_currentUser);
        return _currentUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password, {String? displayName}) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (result.user != null && displayName != null && displayName.isNotEmpty) {
        await result.user!.updateDisplayName(displayName);
        await result.user!.reload();
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
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
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user != null) {
        _currentUser = AppwriteUser.fromFirebaseUser(user);
        _authStateController.add(_currentUser);
      }
    } catch (e) {
      // Handle error silently
    }
  }
  
  // Test network connectivity
  Future<bool> testConnectivity() async {
    try {
      // Try to access Firebase auth to test connection
      _auth.currentUser; // This will throw if Firebase is not accessible
      return true; // If we can access Firebase, connection is good
    } catch (e) {
      return false;
    }
  }

  // Send password recovery email
  Future<void> sendPasswordRecovery(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'Failed to send password recovery email. Please try again.';
    }
  }
  
  // Change password (requires current user to be signed in)
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in.';
      }
      
      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'Failed to change password. Please try again.';
    }
  }
  
  // Handle Firebase Auth exceptions
  String _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Invalid password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please wait a few minutes before trying again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'requires-recent-login':
        return 'Please sign in again to change your password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
  
  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
