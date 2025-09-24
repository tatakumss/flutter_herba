import 'package:firebase_auth/firebase_auth.dart';

// Authentication Service
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
  
  // Register with email and password without auto sign-in
  Future<bool> registerWithEmailAndPassword(String email, String password, {String? displayName}) async {
    try {
      // Create account without signing in by using a temporary auth instance
      final tempAuth = FirebaseAuth.instance;
      final credential = await tempAuth.createUserWithEmailAndPassword(email: email, password: password);
      
      // Update display name if provided using UserProfile
      if (displayName != null && displayName.isNotEmpty && credential.user != null) {
        try {
          await credential.user!.updateProfile(displayName: displayName);
        } catch (e) {
          // If updating display name fails, we still want to return success
          // The user account was created successfully
          print('Warning: Could not update display name: $e');
        }
      }
      
      // Sign out immediately to prevent auto sign-in
      await tempAuth.signOut();
      
      return true;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred during registration. Please try again.';
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
}
