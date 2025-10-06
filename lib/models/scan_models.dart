import 'package:cloud_firestore/cloud_firestore.dart';

// Scan result model for Firestore
class ScanResult {
  final String id;
  final String userId;
  final String plantName;
  final double confidence;
  final String? imageUrl;
  final DateTime scannedAt;
  final Map<String, dynamic>? additionalData;
  final bool isIdentified;
  final List<PlantCandidate>? candidates;

  ScanResult({
    required this.id,
    required this.userId,
    required this.plantName,
    required this.confidence,
    this.imageUrl,
    required this.scannedAt,
    this.additionalData,
    required this.isIdentified,
    this.candidates,
  });

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'plantName': plantName,
      'confidence': confidence,
      'imageUrl': imageUrl,
      'scannedAt': Timestamp.fromDate(scannedAt),
      'additionalData': additionalData ?? {},
      'isIdentified': isIdentified,
      'candidates': candidates?.map((c) => c.toMap()).toList() ?? [],
    };
  }

  // Create from Firestore document
  factory ScanResult.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScanResult(
      id: doc.id,
      userId: data['userId'] ?? '',
      plantName: data['plantName'] ?? 'Unknown',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data['imageUrl'],
      scannedAt: (data['scannedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      additionalData: data['additionalData'] as Map<String, dynamic>?,
      isIdentified: data['isIdentified'] ?? false,
      candidates: (data['candidates'] as List?)
          ?.map((c) => PlantCandidate.fromMap(c as Map<String, dynamic>))
          .toList(),
    );
  }

  // Create from local scan data
  factory ScanResult.fromScanData({
    required String userId,
    required String plantName,
    required double confidence,
    String? imageUrl,
    Map<String, dynamic>? additionalData,
    List<PlantCandidate>? candidates,
  }) {
    return ScanResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      plantName: plantName,
      confidence: confidence,
      imageUrl: imageUrl,
      scannedAt: DateTime.now(),
      additionalData: additionalData,
      isIdentified: confidence > 0.5, // Threshold for identification
      candidates: candidates,
    );
  }
}

// Plant candidate model
class PlantCandidate {
  final String name;
  final double confidence;
  final String? description;
  final Map<String, dynamic>? metadata;

  PlantCandidate({
    required this.name,
    required this.confidence,
    this.description,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'confidence': confidence,
      'description': description,
      'metadata': metadata ?? {},
    };
  }

  factory PlantCandidate.fromMap(Map<String, dynamic> map) {
    return PlantCandidate(
      name: map['name'] ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      description: map['description'],
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

// Collection item model for user's plant collections
class CollectionItem {
  final String id;
  final String userId;
  final String plantName;
  final String? imageUrl;
  final String? imageData; // base64-encoded image bytes (if stored directly in Firestore)
  final DateTime addedAt;
  final String? notes;
  final Map<String, dynamic>? plantInfo;
  final bool isFavorite;

  CollectionItem({
    required this.id,
    required this.userId,
    required this.plantName,
    this.imageUrl,
    this.imageData,
    required this.addedAt,
    this.notes,
    this.plantInfo,
    this.isFavorite = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'plantName': plantName,
      'imageUrl': imageUrl,
      'imageData': imageData,
      'addedAt': Timestamp.fromDate(addedAt),
      'notes': notes,
      'plantInfo': plantInfo ?? {},
      'isFavorite': isFavorite,
    };
  }

  factory CollectionItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CollectionItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      plantName: data['plantName'] ?? '',
      imageUrl: data['imageUrl'],
      imageData: data['imageData'],
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: data['notes'],
      plantInfo: data['plantInfo'] as Map<String, dynamic>?,
      isFavorite: data['isFavorite'] ?? false,
    );
  }

  factory CollectionItem.fromScanResult(ScanResult scanResult, {String? notes}) {
    return CollectionItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: scanResult.userId,
      plantName: scanResult.plantName,
      imageUrl: scanResult.imageUrl,
      imageData: scanResult.additionalData != null ? scanResult.additionalData!['imageData'] as String? : null,
      addedAt: DateTime.now(),
      notes: notes,
      plantInfo: scanResult.additionalData,
      isFavorite: false,
    );
  }
}
