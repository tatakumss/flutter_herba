import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

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
  final FirestoreService _firestoreService = FirestoreService();
  final StreamController<AppwriteUser?> _authStateController = StreamController<AppwriteUser?>.broadcast();
  AppwriteUser? _currentUser;

  // Get current user
  AppwriteUser? get currentUser => _currentUser;
  
  // Auth state stream
  Stream<AppwriteUser?> get authStateChanges => _authStateController.stream;
  
  // Initialize auth service with Firebase
  Future<void> init({bool autoLogin = true}) async {
    
    // Listen to Firebase auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _currentUser = AppwriteUser.fromFirebaseUser(user);
      } else {
        _currentUser = null;
      }
      _authStateController.add(_currentUser);
    });
    
    // Set initial user state - keep existing sessions active
    final user = _auth.currentUser;
    if (user != null) {
      _currentUser = AppwriteUser.fromFirebaseUser(user);
      
      // Ensure user profile exists in Firestore
      try {
        final userExists = await _firestoreService.userExists(user.uid);
        if (!userExists) {
          // Create missing Firestore profile
          final userProfile = UserProfile.fromFirebaseUser(user);
          await _firestoreService.createOrUpdateUser(userProfile);
        }
      } catch (firestoreError) {
        // Continue with login even if Firestore fails
      }
    } else {
      _currentUser = null;
    }
    _authStateController.add(_currentUser);
  }
  
  // Sign in with email and password (logs user in directly)
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password.';
      }

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (result.user != null) {
        // Ensure user profile exists in Firestore
        try {
          final userExists = await _firestoreService.userExists(result.user!.uid);
          if (!userExists) {
            // Create missing Firestore profile
            final userProfile = UserProfile.fromFirebaseUser(result.user!);
            await _firestoreService.createOrUpdateUser(userProfile);
          }
        } catch (firestoreError) {
          // Continue with login even if Firestore fails
        }
        
        _currentUser = AppwriteUser.fromFirebaseUser(result.user!);
        _authStateController.add(_currentUser);
        return true; // Login successful
      }
      return false;
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw 'Login failed: ${e.toString()}';
    }
  }
  
  // Register with email and password
  Future<bool> registerWithEmailAndPassword(String email, String password, {String? displayName}) async {
    UserCredential? result;
    
    try {
      // Create Firebase Auth account
      result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (result.user != null) {
        // Update Firebase Auth profile
        if (displayName != null && displayName.isNotEmpty) {
          await result.user!.updateDisplayName(displayName);
          await result.user!.reload();
        }
        
        // Try to create user profile in Firestore
        try {
          final userProfile = UserProfile.fromFirebaseUser(result.user!);
          await _firestoreService.createOrUpdateUser(userProfile);
        } catch (firestoreError) {
          // If Firestore fails, continue anyway - profile can be created later
          // Don't throw error, just log it for debugging
          // The user can still use the app with Firebase Auth only
        }
        
        // Sign out after registration to require manual login
        await _auth.signOut();
        _currentUser = null;
        _authStateController.add(null);
      }
      
      return true;
    } on FirebaseAuthException catch (e) {
      // If Firebase Auth fails, clean up and throw error
      if (result?.user != null) {
        try {
          await result!.user!.delete();
        } catch (deleteError) {
          // Ignore deletion errors
        }
      }
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      // If any other error occurs after account creation, don't delete the account
      // The user can try to login later and the Firestore profile will be created then
      if (result?.user == null) {
        throw 'Registration failed. Please try again.';
      } else {
        // Account was created but something else failed
        throw 'Account created successfully. Please try logging in.';
      }
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
  
  // Get user profile from Firestore
  Future<UserProfile?> getUserProfile() async {
    if (_currentUser == null) return null;
    
    try {
      return await _firestoreService.getUserProfile(_currentUser!.uid);
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  // Update user profile in Firestore
  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? preferences,
  }) async {
    if (_currentUser == null) return;

    try {
      // Update Firebase Auth profile if needed
      if (displayName != null) {
        await _auth.currentUser?.updateDisplayName(displayName);
      }
      // Skip Firebase Auth photoURL update for base64 images (too long)
      // Base64 images will only be stored in Firestore
      if (photoUrl != null && !photoUrl.startsWith('data:image')) {
        await _auth.currentUser?.updatePhotoURL(photoUrl);
      }

      // Update Firestore profile
      final currentProfile = await _firestoreService.getUserProfile(_currentUser!.uid);
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(
          displayName: displayName,
          photoUrl: photoUrl,
          preferences: preferences,
        );
        await _firestoreService.createOrUpdateUser(updatedProfile);
      }

      // Refresh current user
      await refreshUser();
    } catch (e) {
      throw 'Failed to update profile: $e';
    }
  }

  // Get user profile stream for real-time updates
  Stream<UserProfile?> getUserProfileStream() {
    if (_currentUser == null) {
      return Stream.value(null);
    }
    return _firestoreService.getUserProfileStream(_currentUser!.uid);
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}
