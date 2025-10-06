// Appwrite service removed - no longer using cloud backend
class AppwriteService {
  // Singleton pattern
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  static void initialize() {
    // No initialization needed - Appwrite removed
  }
}
