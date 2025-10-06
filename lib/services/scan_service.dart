
// Scan service removed - no longer using cloud backend
class ScanService {
  static final ScanService _instance = ScanService._internal();
  factory ScanService() => _instance;
  ScanService._internal();

  /// Save a scan result (now returns null)
  Future<String?> saveScan({
    required String plantName,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
    String? oodReason,
    double? oodScore,
  }) async {
    // No cloud backend - cannot save scan
    return null;
  }

  /// Save scan result (alternative method name - now returns null)
  Future<String?> saveScanResult({
    required String plantName,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
    String? oodReason,
    double? oodScore,
  }) async {
    // No cloud backend - cannot save scan
    return null;
  }

  /// Get all scans (now returns empty list)
  Future<List<Map<String, dynamic>>> getScans() async {
    // No cloud backend - return empty scans
    return [];
  }

  /// Delete a scan (now returns false)
  Future<bool> deleteScan(String documentId) async {
    // No cloud backend - cannot delete scan
    return false;
  }

  /// Get user's recent scans (now returns empty list)
  Future<List<Map<String, dynamic>>> getUserScans({int limit = 20}) async {
    // No cloud backend - return empty scans
    return [];
  }
}
