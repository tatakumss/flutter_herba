import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/scan_models.dart';
// Enhanced scan service with Firestore integration
class ScanService {
  static final ScanService _instance = ScanService._internal();
  factory ScanService() => _instance;
  ScanService._internal();

  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save a scan result with image to Firestore
  Future<String?> saveScan({
    required String plantName,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
    String? oodReason,
    double? oodScore,
    File? imageFile,
    Uint8List? imageBytes,
    // Strongly recommended fields for validation/dataset assessment
    String? preferredDataset, // 'mendeley' | 'kaggle'
    String? selectedLabel,
    double? selectedConfidence,
    double? mendeleyTop,
    double? kaggleTop,
    String? selectedFrom, // e.g., 'combo'
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create scan result
      final scanId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Convert image to base64 if provided
      String? imageData;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        imageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } else if (imageBytes != null) {
        imageData = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      }

      // Convert candidates to PlantCandidate objects (support both name/confidence and label/score keys)
      final plantCandidates = candidates.map((c) => PlantCandidate(
        name: (c['name'] ?? c['label'] ?? '').toString(),
        confidence: (c['confidence'] is num)
            ? (c['confidence'] as num).toDouble()
            : ((c['score'] is num) ? (c['score'] as num).toDouble() : 0.0),
        description: c['description'],
        metadata: c,
      )).toList();

      // Create scan result
      final scanResult = ScanResult(
        id: scanId,
        userId: user.uid,
        plantName: plantName,
        confidence: confidence,
        imageUrl: imageData, // Store base64 data instead of URL
        scannedAt: DateTime.now(),
        additionalData: {
          'isOod': isOod,
          'oodReason': oodReason,
          'oodScore': oodScore,
          if (preferredDataset != null) 'preferredDataset': preferredDataset,
          if (selectedLabel != null) 'selectedLabel': selectedLabel,
          if (selectedConfidence != null) 'selectedConfidence': selectedConfidence,
          if (mendeleyTop != null) 'mendeleyTop': mendeleyTop,
          if (kaggleTop != null) 'kaggleTop': kaggleTop,
          if (selectedFrom != null) 'selectedFrom': selectedFrom,
        },
        isIdentified: !isOod && confidence > 0.5,
        candidates: plantCandidates,
      );

      // Save to Firestore
      await _firestoreService.saveScanResult(scanResult);
      
      return scanId;
    } catch (e) {
      // Log the error for debugging (avoid print in production)
      debugPrint('Error saving scan: $e');
      return null;
    }
  }


  /// Get all scans for current user
  Future<List<Map<String, dynamic>>> getScans() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final scans = await _firestoreService.getUserScans(user.uid);
      return scans.map((scan) => {
        'id': scan.id,
        'plantName': scan.plantName,
        'confidence': scan.confidence,
        'imageUrl': scan.imageUrl,
        'scannedAt': scan.scannedAt.toIso8601String(),
        'isIdentified': scan.isIdentified,
        'candidates': scan.candidates?.map((c) => c.toMap()).toList() ?? [],
        'additionalData': scan.additionalData,
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete a scan
  Future<bool> deleteScan(String documentId) async {
    try {
      await _firestoreService.deleteScanResult(documentId);
      return true;
    } catch (e) {
      return false;
    }
  }


  /// Get scan statistics for current user
  Future<Map<String, dynamic>> getScanStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      return await _firestoreService.getUserScanStats(user.uid);
    } catch (e) {
      return {};
    }
  }
}
