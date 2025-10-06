import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/scan_models.dart';

class FeedbackService {
  // Singleton pattern
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Submit general feedback/suggestion
  Future<bool> submitFeedback({
    required String message,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final feedback = FeedbackItem.createSuggestion(
        userId: userId,
        message: message,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toFirestore());

      return true;
    } catch (e) {
      return false;
    }
  }

  // Submit error report with scan context
  Future<bool> submitErrorReport({
    required String message,
    required String scanId,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final feedback = FeedbackItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: 'error',
        message: message,
        timestamp: DateTime.now(),
        scanId: scanId,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toFirestore());

      return true;
    } catch (e) {
      return false;
    }
  }

  // Submit error report with scan context and detailed scan information
  Future<bool> submitErrorReportWithScan({
    required String message,
    required String scanId,
    Map<String, dynamic>? scanContext,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final feedback = FeedbackItem.createErrorReport(
        userId: userId,
        message: message,
        scanId: scanId,
        scanContext: scanContext ?? {},
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toFirestore());

      return true;
    } catch (e) {
      return false;
    }
  }

  // Submit improvement suggestion
  Future<bool> submitImprovementSuggestion({
    required String message,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      final feedback = FeedbackItem.createSuggestion(
        userId: userId,
        message: message,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toFirestore());

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get user's feedback history
  Future<List<FeedbackItem>> getUserFeedback() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return [];

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FeedbackItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get user's feedback stream for real-time updates
  Stream<List<FeedbackItem>> getUserFeedbackStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('feedback')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeedbackItem.fromFirestore(doc))
            .toList());
  }

  // Update feedback status (for admin use)
  Future<bool> updateFeedbackStatus({
    required String feedbackId,
    required String status,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedbackId)
          .update({'status': status});

      return true;
    } catch (e) {
      return false;
    }
  }

  // Delete feedback item
  Future<bool> deleteFeedback(String feedbackId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .doc(feedbackId)
          .delete();

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get feedback statistics for user
  Future<Map<String, int>> getFeedbackStats() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return {};

      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('feedback')
          .get();

      final stats = <String, int>{
        'total': snapshot.docs.length,
        'errors': 0,
        'suggestions': 0,
        'pending': 0,
        'reviewed': 0,
        'resolved': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? 'suggestion';
        final status = data['status'] as String? ?? 'pending';

        stats[type] = (stats[type] ?? 0) + 1;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      return {};
    }
  }
}
