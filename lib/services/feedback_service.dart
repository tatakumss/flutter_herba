// Feedback service removed - no longer using cloud backend
class FeedbackService {
  // Singleton pattern
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  // Submit general feedback/suggestion (now returns false)
  Future<bool> submitFeedback({
    required String message,
  }) async {
    // No cloud backend - cannot submit feedback
    return false;
  }

  // Submit error report with scan context (now returns false)
  Future<bool> submitErrorReport({
    required String message,
    required String scanId,
  }) async {
    // No cloud backend - cannot submit error report
    return false;
  }

  // Submit error report with scan context (now returns false)
  Future<bool> submitErrorReportWithScan({
    required String message,
    required String scanId,
  }) async {
    // No cloud backend - cannot submit error report
    return false;
  }

  // Submit improvement suggestion (now returns false)
  Future<bool> submitImprovementSuggestion({
    required String message,
  }) async {
    // No cloud backend - cannot submit suggestion
    return false;
  }
}
