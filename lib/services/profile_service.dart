// ignore_for_file: deprecated_member_use

import 'package:appwrite/appwrite.dart';
import 'appwrite_service.dart';
import '../config/app_config.dart';

class ProfileService {
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    try {
      final document = await AppwriteService.databases.getDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.usersCollectionId,
        documentId: uid,
      );
      return document.data;
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Document doesn't exist
        return null;
      }
      throw e;
    }
  }

  Future<void> ensureUserDoc(String uid, {String? email, String? displayName}) async {
    try {
      // Check if document exists
      await AppwriteService.databases.getDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.usersCollectionId,
        documentId: uid,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Document doesn't exist, create it
        await AppwriteService.databases.createDocument(
          databaseId: AppConfig.appwriteDatabaseId,
          collectionId: AppConfig.usersCollectionId,
          documentId: uid,
          data: {
            'name': displayName ?? email ?? '',
            'email': email ?? '',
            'birthday': null,
            'photoUrl': null,
            'bio': null,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          },
        );
      } else {
        throw e;
      }
    }
  }

  Future<void> updateProfile(
    String uid, {
    String? name,
    DateTime? birthday,
    String? photoUrl,
    String? bio,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    
    if (name != null) data['name'] = name;
    if (birthday != null) {
      data['birthday'] = birthday.toIso8601String();
    } else {
      data['birthday'] = null;
    }
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    if (bio != null) data['bio'] = bio;

    await AppwriteService.databases.updateDocument(
      databaseId: AppConfig.appwriteDatabaseId,
      collectionId: AppConfig.usersCollectionId,
      documentId: uid,
      data: data,
    );
  }
}
