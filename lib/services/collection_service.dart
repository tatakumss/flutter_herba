import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollectionService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> saveScan({
    required String name,
    required double confidence,
    required bool isOod,
    required List<Map<String, dynamic>> candidates,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final ref = _db.collection('users').doc(user.uid).collection('collections');
    await ref.add({
      'name': name,
      'confidence': confidence,
      'isOod': isOod,
      'candidates': candidates,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
