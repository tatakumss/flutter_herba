import 'package:appwrite/appwrite.dart';
import 'appwrite_service.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class FeedbackService {
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  /// Submit general feedback to Appwrite database
  /// 
  /// Feedback table structure:
  /// - feedbackId (PK)
  /// - userId 
  /// - message
  /// - timestamp
  Future<String?> submitFeedback({
    required String message,
  }) async {
    try {
      // Get current user info
      final authService = AuthService();
      final user = authService.currentUser;
      
      // Prepare feedback document
      final feedbackData = <String, dynamic>{
        'userId': user?.uid ?? 'anonymous',
        'message': message.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Submit to Appwrite
      final response = await AppwriteService.databases.createDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.feedbackCollectionId,
        documentId: ID.unique(),
        data: feedbackData,
      );

      return response.$id; // Return feedback ID for potential report linking
    } catch (e) {
      // Log error for debugging
      print('FeedbackService: Failed to submit feedback - $e');
      return null;
    }
  }

  /// Submit error report with scan context
  /// 
  /// Report table structure:
  /// - reportId (PK)
  /// - feedbackId (FK) - optional, links to feedback if user provided general feedback
  /// - scanId (FK) - links to the scan being reported
  /// - message
  /// - timestamp
  Future<bool> submitReport({
    required String message,
    required String scanId,
    String? feedbackId, // Optional link to feedback
  }) async {
    try {
      // Prepare report document
      final reportData = <String, dynamic>{
        'scanId': scanId,
        'message': message.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Add feedback link if provided
      if (feedbackId != null) {
        reportData['feedbackId'] = feedbackId;
      }

      // Submit to Appwrite
      await AppwriteService.databases.createDocument(
        databaseId: AppConfig.appwriteDatabaseId,
        collectionId: AppConfig.reportsCollectionId,
        documentId: ID.unique(),
        data: reportData,
      );

      return true;
    } catch (e) {
      // Log error for debugging
      print('FeedbackService: Failed to submit report - $e');
      return false;
    }
  }

  /// Combined method for error reporting with scan context
  /// This creates both a feedback entry and a report entry linked to a scan
  Future<bool> submitErrorReportWithScan({
    required String message,
    required String scanId,
  }) async {
    try {
      // First create the feedback entry
      final feedbackId = await submitFeedback(message: message);
      
      if (feedbackId == null) {
        return false; // Failed to create feedback
      }

      // Then create the report entry linked to the scan and feedback
      return await submitReport(
        message: message,
        scanId: scanId,
        feedbackId: feedbackId,
      );
    } catch (e) {
      print('FeedbackService: Failed to submit error report with scan - $e');
      return false;
    }
  }

  /// Submit improvement suggestion (just feedback, no scan context needed)
  Future<bool> submitImprovementSuggestion({
    required String message,
  }) async {
    final feedbackId = await submitFeedback(message: message);
    return feedbackId != null;
  }
}
