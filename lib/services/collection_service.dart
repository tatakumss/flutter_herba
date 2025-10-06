import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/scan_models.dart';

// Enhanced collection service with Firestore integration
class CollectionService {
  static final CollectionService _instance = CollectionService._internal();
  factory CollectionService() => _instance;
  CollectionService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get user's collections
  Future<List<Map<String, dynamic>>> getCollections() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final collections = await _firestoreService.getUserCollection(user.uid);
      return collections.map((item) => {
        'id': item.id,
        'plantName': item.plantName,
        'imageUrl': item.imageUrl,
        'imageData': item.imageData,
        'addedAt': item.addedAt.toIso8601String(),
        'notes': item.notes,
        'plantInfo': item.plantInfo,
        'isFavorite': item.isFavorite,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Add to collection
  Future<bool> addToCollection(Map<String, dynamic> plantData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Prefer explicit plantInfo if provided; else build a compact map without imageData/imageUrl
      final Map<String, dynamic>? providedInfo = plantData['plantInfo'] as Map<String, dynamic>?;
      final compactInfo = providedInfo ?? {
        if (plantData.containsKey('confidence')) 'confidence': plantData['confidence'],
        if (plantData.containsKey('isOod')) 'isOod': plantData['isOod'],
        if (plantData.containsKey('oodReason')) 'oodReason': plantData['oodReason'],
        if (plantData.containsKey('oodScore')) 'oodScore': plantData['oodScore'],
        if (plantData.containsKey('candidates')) 'candidates': plantData['candidates'],
        if (plantData.containsKey('scannedAt')) 'scannedAt': plantData['scannedAt'],
      };

      final collectionItem = CollectionItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: user.uid,
        plantName: plantData['plantName'] ?? 'Unknown Plant',
        imageUrl: plantData['imageUrl'],
        imageData: plantData['imageData'],
        addedAt: DateTime.now(),
        notes: plantData['notes'],
        plantInfo: compactInfo,
        isFavorite: plantData['isFavorite'] ?? false,
      );

      await _firestoreService.addToCollection(collectionItem);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove from collection
  Future<bool> removeFromCollection(String documentId) async {
    try {
      await _firestoreService.removeFromCollection(documentId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if plant is in collection
  Future<bool> isInCollection(String plantName) async {
    try {
      final collections = await getCollections();
      return collections.any((item) => 
        item['plantName']?.toString().toLowerCase() == plantName.toLowerCase());
    } catch (e) {
      return false;
    }
  }

  /// Add scan result to collection
  Future<bool> addScanToCollection(ScanResult scanResult, {String? notes}) async {
    try {
      final collectionItem = CollectionItem.fromScanResult(scanResult, notes: notes);
      await _firestoreService.addToCollection(collectionItem);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update collection item
  Future<bool> updateCollectionItem(String itemId, Map<String, dynamic> updates) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Get existing item first
      final collections = await getCollections();
      final existingItem = collections.firstWhere(
        (item) => item['id'] == itemId,
        orElse: () => <String, dynamic>{},
      );

      if (existingItem.isEmpty) return false;

      // Create updated collection item
      final updatedItem = CollectionItem(
        id: itemId,
        userId: user.uid,
        plantName: updates['plantName'] ?? existingItem['plantName'],
        imageUrl: updates['imageUrl'] ?? existingItem['imageUrl'],
        addedAt: DateTime.parse(existingItem['addedAt']),
        notes: updates['notes'] ?? existingItem['notes'],
        plantInfo: updates['plantInfo'] ?? existingItem['plantInfo'],
        isFavorite: updates['isFavorite'] ?? existingItem['isFavorite'],
      );

      await _firestoreService.updateCollectionItem(updatedItem);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get scans (for backward compatibility)
  Future<List<Map<String, dynamic>>> getScans() async {
    return await getCollections();
  }

  /// Save scan (for backward compatibility)
  Future<Map<String, dynamic>> saveScan({
    required String plantName,
    required double confidence,
    String? additionalInfo,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final plantData = {
        'plantName': plantName,
        'confidence': confidence,
        'additionalInfo': additionalInfo,
        'scannedAt': DateTime.now().toIso8601String(),
      };

      final success = await addToCollection(plantData);
      return success ? {'success': true, 'id': DateTime.now().millisecondsSinceEpoch.toString()} : {};
    } catch (e) {
      return {};
    }
  }
}
