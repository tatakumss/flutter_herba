import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snap = await _userDoc(uid).get();
    return snap.data();
  }

  Future<void> ensureUserDoc(String uid, {String? email, String? displayName}) async {
    final ref = _userDoc(uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': displayName ?? email ?? '',
        'birthday': null,
        'photoUrl': null,
        'bio': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
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
      if (name != null) 'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (birthday != null) {
      data['birthday'] = Timestamp.fromDate(birthday);
    } else if (birthday == null) {
      // Explicitly allow clearing birthday by passing null
      data['birthday'] = null;
    }
    if (photoUrl != null) {
      data['photoUrl'] = photoUrl;
    }
    if (bio != null) {
      data['bio'] = bio;
    }
    await _userDoc(uid).set(data, SetOptions(merge: true));
  }
}
