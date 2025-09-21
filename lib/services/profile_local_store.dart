import 'package:shared_preferences/shared_preferences.dart';

class ProfileLocalStore {
  static const _kName = 'profile_name';
  static const _kBirthdayIso = 'profile_birthday_iso';
  static const _kPhotoUrl = 'profile_photo_url';

  Future<void> save({String? name, DateTime? birthday, String? photoUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      await prefs.setString(_kName, name);
    }
    if (birthday != null) {
      await prefs.setString(_kBirthdayIso, birthday.toIso8601String());
    }
    if (photoUrl != null) {
      await prefs.setString(_kPhotoUrl, photoUrl);
    }
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kName);
    final bdayIso = prefs.getString(_kBirthdayIso);
    final photoUrl = prefs.getString(_kPhotoUrl);
    DateTime? birthday;
    if (bdayIso != null && bdayIso.isNotEmpty) {
      birthday = DateTime.tryParse(bdayIso);
    }
    if (name == null && birthday == null && photoUrl == null) {
      return null;
    }
    return {
      'name': name,
      'birthday': birthday,
      'photoUrl': photoUrl,
    };
  }
}
