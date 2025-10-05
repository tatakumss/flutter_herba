import 'package:shared_preferences/shared_preferences.dart';

class ProfileLocalStore {
  static const _kName = 'profile_name';
  static const _kPhotoUrl = 'profile_photo_url';

  Future<void> save({String? name, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString(_kName, name);
    }
    if (photoUrl != null) {
      await prefs.setString(_kPhotoUrl, photoUrl);
    }
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    final photoUrl = prefs.getString(_kPhotoUrl);
    
    if (name == null && photoUrl == null) {
      return null;
    }
    return {
      'name': name,
      'photoUrl': photoUrl,
    };
  }
}
