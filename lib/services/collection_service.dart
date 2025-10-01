import 'package:appwrite/appwrite.dart';
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
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    await AppwriteService.databases.createDocument(
      databaseId: AppConfig.appwriteDatabaseId,
      collectionId: AppConfig.scansCollectionId,
      documentId: ID.unique(),
      data: {
        'userId': user.uid,
        'name': name,
        'confidence': confidence,
        'isOod': isOod,
        'candidates': candidates,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
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
          Query.equal('userId', user.uid),
          Query.orderDesc('createdAt'),
        ],
      );

      return response.documents.map((doc) => doc.data).toList();
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        // Collection doesn't exist yet
        return [];
      }
      throw e;
    }
  }
}
