import 'package:appwrite/appwrite.dart';
import 'appwrite_service.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'dart:typed_data';

class ScanService {
  static final ScanService _instance = ScanService._internal();
  factory ScanService() => _instance;
  ScanService._internal();

  /// Save scan result to database and return scan ID
  /// 
  /// Scan table structure should include:
  /// - scanId (PK)
  /// - userId
  /// - plantName
  /// - confidence
  /// - isOod
  /// - timestamp
  /// - imageUrl (optional)
  /// - candidates (JSON string)
  Future<String?> saveScanResult({
    required String plantName,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
    Uint8List? imageBytes,
    String? oodReason,
    double? oodScore,
  }) async {
    try {
      // Get current user info
      final authService = AuthService();
      final user = authService.currentUser;
      
      // Prepare scan document
      final scanData = <String, dynamic>{
        'userId': user?.uid ?? 'anonymous',
        'plantName': plantName,
        'confidence': confidence,
        'isOod': isOod,
        'timestamp': DateTime.now().toIso8601String(),
        'candidates': candidates, // Appwrite handles JSON automatically
      };

      // Add optional OOD data
      if (oodReason != null) {
        scanData['oodReason'] = oodReason;
      }
      if (oodScore != null) {
        scanData['oodScore'] = oodScore;
      }

      // Create scan document
      final response = await AppwriteService.databases.createDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.scansCollectionId,
        documentId: ID.unique(),
        data: scanData,
      );

      // Optionally save image to storage
      if (imageBytes != null) {
        try {
          await AppwriteService.storage.createFile(
            bucketId: AppConfig.scansBucketId,
            fileId: response.$id, // Use same ID as scan document
            file: InputFile.fromBytes(
              bytes: imageBytes,
              filename: '${response.$id}.jpg',
            ),
          );
          
          // Update scan document with image URL
          await AppwriteService.databases.updateDocument(
            databaseId: AppConfig.appwriteDatabaseId,
            collectionId: AppConfig.scansCollectionId,
            documentId: response.$id,
            data: {
              'imageUrl': '${AppConfig.scansBucketId}/${response.$id}',
            },
          );
        } catch (e) {
          print('ScanService: Failed to save image - $e');
          // Continue without image - scan data is still saved
        }
      }

      return response.$id; // Return scan ID
    } catch (e) {
      print('ScanService: Failed to save scan result - $e');
      return null;
    }
  }

  /// Get scan by ID
  Future<Map<String, dynamic>?> getScanById(String scanId) async {
    try {
      final response = await AppwriteService.databases.getDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.scansCollectionId,
        documentId: scanId,
      );
      return response.data;
    } catch (e) {
      print('ScanService: Failed to get scan - $e');
      return null;
    }
  }

  /// Get user's recent scans
  Future<List<Map<String, dynamic>>> getUserScans({int limit = 20}) async {
    try {
      final authService = AuthService();
      final user = authService.currentUser;
      
      if (user == null) return [];

      final response = await AppwriteService.databases.listDocuments(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.scansCollectionId,
        queries: [
          Query.equal('userId', user.uid),
          Query.orderDesc('timestamp'),
          Query.limit(limit),
        ],
      );

      return response.documents.map((doc) => doc.data).toList();
    } catch (e) {
      print('ScanService: Failed to get user scans - $e');
      return [];
    }
  }
}
