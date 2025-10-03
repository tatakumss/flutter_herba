import 'dart:typed_data';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'appwrite_service.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class CollectionService {
  final AuthService _authService = AuthService();

  Future<void> saveScan({
    required String name,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
    required Uint8List imageBytes,
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    // 1) Upload image to Storage under a per-user path (pseudo-folder)
    final fileId = ID.unique();
    final filename = '${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    models.File? file;
    try {
      file = await AppwriteService.storage.createFile(
        bucketId: AppConfig.scansBucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: imageBytes,
          filename: filename,
          contentType: 'image/jpeg',
        ),
        permissions: [
          Permission.read(Role.user(user.uid)),
          Permission.write(Role.user(user.uid)),
        ],
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        throw StateError('Appwrite Storage bucket "${AppConfig.scansBucketId}" not found (404). Please create it and grant user access.');
      }
      rethrow;
    }

    // 2) Create scan document with reference to file
    try {
      await AppwriteService.databases.createDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.scansCollectionId,
        documentId: ID.unique(),
        data: {
          // Use schema keys with capital D to match your collection definition
          'userID': user.uid,
          'name': name,
          'confidence': confidence,
          'isOod': isOod,
          // Store as JSON string if the collection doesn't support JSON type
          'candidates': jsonEncode(candidates),
          // Write both camel and capital-D variants to match schema
          'fileID': file.$id,
          'bucketID': AppConfig.scansBucketId,
          'filename': filename,
        },
        permissions: [
          Permission.read(Role.user(user.uid)),
          Permission.write(Role.user(user.uid)),
        ],
      );
    } on AppwriteException catch (e) {
      // ignore: avoid_print
      print('Appwrite DB createDocument failed: code=${e.code} message=${e.message}');
      if (e.code == 404) {
        throw StateError('Appwrite database/collection "${AppConfig.appwriteDatabaseId}/${AppConfig.scansCollectionId}" not found (404). Please provision them.');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getScans() async {
    final user = _authService.currentUser;
    if (user == null) {
      return [];
    }

    try {
      final response = await AppwriteService.databases.listDocuments(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.scansCollectionId,
        queries: [
          Query.equal('userID', user.uid),
          // Order by Appwrite system field `$createdAt`
          Query.orderDesc(r'$createdAt'),
        ],
      );

      return response.documents.map((doc) {
        final data = Map<String, dynamic>.from(doc.data);
        final c = data['candidates'];
        if (c is String) {
          try {
            data['candidates'] = jsonDecode(c);
          } catch (_) {
            // leave as string if decode fails
          }
        }
        return data;
      }).toList();
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Collection doesn't exist yet
        return [];
      }
      throw e;
    }
  }
}
