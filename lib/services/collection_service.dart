import 'dart:typed_data';

// Collection service removed - no longer using cloud storage
class CollectionService {
  // Singleton pattern
  static final CollectionService _instance = CollectionService._internal();
  factory CollectionService() => _instance;
  CollectionService._internal();

  // Get user collections (now returns empty list)
  Future<List<Map<String, dynamic>>> getUserCollections() async {
    // No cloud storage - return empty collections
    return [];
  }

  // Save scan to collection (now returns false)
  Future<bool> saveScanToCollection({
    required String plantName,
    required double confidence,
    required Uint8List imageBytes,
    String? additionalInfo,
  }) async {
    // No cloud storage - cannot save
    return false;
  }

  // Get scans (now returns empty list)
  Future<List<Map<String, dynamic>>> getScans() async {
    // No cloud storage - return empty scans
    return [];
  }

  // Save scan (now returns empty map)
  Future<Map<String, dynamic>> saveScan({
    required String plantName,
    required double confidence,
    required Uint8List imageBytes,
    String? additionalInfo,
  }) async {
    // No cloud storage - return empty result
    return {};
  }
}
