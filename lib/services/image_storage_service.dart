import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ImageStorageService {
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Upload profile image
  Future<String?> uploadProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_images').child(fileName);

      // Compress and upload
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload profile image from bytes
  Future<String?> uploadProfileImageFromBytes(Uint8List imageBytes) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_images').child(fileName);

      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload scan image
  Future<String?> uploadScanImage(File imageFile, String scanId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'scan_${scanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('scan_images').child(user.uid).child(fileName);

      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'scanId': scanId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Upload scan image from bytes
  Future<String?> uploadScanImageFromBytes(Uint8List imageBytes, String scanId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final fileName = 'scan_${scanId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('scan_images').child(user.uid).child(fileName);

      final uploadTask = ref.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': user.uid,
            'scanId': scanId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  // Delete image by URL
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete old profile images for user
  Future<void> deleteOldProfileImages(String userId) async {
    try {
      final ref = _storage.ref().child('profile_images');
      final result = await ref.listAll();
      
      for (final item in result.items) {
        final metadata = await item.getMetadata();
        if (metadata.customMetadata?['userId'] == userId) {
          await item.delete();
        }
      }
    } catch (e) {
      // Silently handle deletion errors
    }
  }

  // Get storage usage for user
  Future<int> getUserStorageUsage(String userId) async {
    try {
      int totalSize = 0;
      
      // Check profile images
      final profileRef = _storage.ref().child('profile_images');
      final profileResult = await profileRef.listAll();
      
      for (final item in profileResult.items) {
        final metadata = await item.getMetadata();
        if (metadata.customMetadata?['userId'] == userId) {
          totalSize += metadata.size ?? 0;
        }
      }
      
      // Check scan images
      final scanRef = _storage.ref().child('scan_images').child(userId);
      try {
        final scanResult = await scanRef.listAll();
        for (final item in scanResult.items) {
          final metadata = await item.getMetadata();
          totalSize += metadata.size ?? 0;
        }
      } catch (e) {
        // User might not have scan images yet
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  // Check if Firebase Storage is available
  Future<bool> isStorageAvailable() async {
    try {
      await _storage.ref().child('test').getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }
}
