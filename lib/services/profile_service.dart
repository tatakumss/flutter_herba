// ignore_for_file: deprecated_member_use

class ProfileService {
  // Get user profile (now returns null)
  Future<Map<String, dynamic>?> getUserProfile() async {
    // No cloud backend - return null
    return null;
  }

  // Create or update user profile (now returns false)
  Future<bool> saveUserProfile({
    required String displayName,
    String? bio,
    String? profileImageUrl,
  }) async {
    // No cloud backend - cannot save profile
    return false;
  }
}
