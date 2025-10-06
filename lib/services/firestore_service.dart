// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scan_models.dart';

// User model for Firestore
class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? preferences;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.preferences,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'preferences': preferences ?? {},
    };
  }

  // Create from Firestore document
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: data['uid'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      preferences: data['preferences'] as Map<String, dynamic>?,
    );
  }

  // Create from Firebase User
  factory UserProfile.fromFirebaseUser(User user) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Copy with updated fields
  UserProfile copyWith({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? preferences,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      preferences: preferences ?? this.preferences,
    );
  }
}

// Firestore service for user data management
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _usersCollection = 'users';
  final String _scansCollection = 'scans';
  final String _collectionsCollection = 'collections';

  // Check if Firestore is available
  Future<bool> isFirestoreAvailable() async {
    try {
      await _firestore.enableNetwork();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Handle Firestore exceptions with user-friendly messages
  String _handleFirestoreException(dynamic e) {
    if (e.toString().contains('permission-denied')) {
      return 'Access denied. Please check your permissions.';
    } else if (e.toString().contains('unavailable')) {
      return 'Service temporarily unavailable. Please check your internet connection.';
    } else if (e.toString().contains('not-found')) {
      return 'Requested data not found.';
    } else if (e.toString().contains('already-exists')) {
      return 'Data already exists.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Create or update user profile
  Future<void> createOrUpdateUser(UserProfile userProfile) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userProfile.uid)
          .set(userProfile.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Get user profile by UID
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Update user display name
  Future<void> updateDisplayName(String uid, String displayName) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'displayName': displayName,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update display name: $e');
    }
  }

  // Update user photo URL
  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'photoUrl': photoUrl,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update photo URL: $e');
    }
  }

  // Update user preferences
  Future<void> updatePreferences(String uid, Map<String, dynamic> preferences) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .update({
        'preferences': preferences,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Failed to update preferences: $e');
    }
  }

  // Delete user profile
  Future<void> deleteUser(String uid) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete user profile: $e');
    }
  }

  // Get user profile stream for real-time updates
  Stream<UserProfile?> getUserProfileStream(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    });
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  // Get all users (admin function - use with caution)
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .get();

      return querySnapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Test Firestore connection
  Future<bool> testConnection() async {
    try {
      // Try to read from a test collection
      await _firestore
          .collection('test')
          .limit(1)
          .get();
      return true;
    } catch (e) {
      return false;
    }
  }

  // SCAN RESULT METHODS
  
  // Save scan result to Firestore
  Future<void> saveScanResult(ScanResult scanResult) async {
    try {
      await _firestore
          .collection(_scansCollection)
          .doc(scanResult.id)
          .set(scanResult.toFirestore());
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Get user's scan results
  Future<List<ScanResult>> getUserScans(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_scansCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('scannedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => ScanResult.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Get scan result by ID
  Future<ScanResult?> getScanResult(String scanId) async {
    try {
      final doc = await _firestore
          .collection(_scansCollection)
          .doc(scanId)
          .get();

      if (doc.exists) {
        return ScanResult.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Delete scan result
  Future<void> deleteScanResult(String scanId) async {
    try {
      await _firestore
          .collection(_scansCollection)
          .doc(scanId)
          .delete();
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // COLLECTION METHODS

  // Add item to user's collection
  Future<void> addToCollection(CollectionItem item) async {
    try {
      await _firestore
          .collection(_collectionsCollection)
          .doc(item.id)
          .set(item.toFirestore());
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Get user's collection items
  Future<List<CollectionItem>> getUserCollection(String userId, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('addedAt', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => CollectionItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Remove item from collection
  Future<void> removeFromCollection(String itemId) async {
    try {
      await _firestore
          .collection(_collectionsCollection)
          .doc(itemId)
          .delete();
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Update collection item
  Future<void> updateCollectionItem(CollectionItem item) async {
    try {
      await _firestore
          .collection(_collectionsCollection)
          .doc(item.id)
          .update(item.toFirestore());
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Get user's scan statistics
  Future<Map<String, dynamic>> getUserScanStats(String userId) async {
    try {
      final scansQuery = await _firestore
          .collection(_scansCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final collectionsQuery = await _firestore
          .collection(_collectionsCollection)
          .where('userId', isEqualTo: userId)
          .get();

      final totalScans = scansQuery.docs.length;
      final identifiedScans = scansQuery.docs
          .where((doc) => doc.data()['isIdentified'] == true)
          .length;
      final totalCollections = collectionsQuery.docs.length;

      return {
        'totalScans': totalScans,
        'identifiedScans': identifiedScans,
        'totalCollections': totalCollections,
        'identificationRate': totalScans > 0 ? identifiedScans / totalScans : 0.0,
      };
    } catch (e) {
      throw Exception(_handleFirestoreException(e));
    }
  }

  // Initialize Firestore settings (call this in main.dart)
  static Future<void> initialize() async {
    try {
      // Enable offline persistence
      await FirebaseFirestore.instance.enablePersistence();
    } catch (e) {
      // Persistence may already be enabled or not supported
    }
  }
}
