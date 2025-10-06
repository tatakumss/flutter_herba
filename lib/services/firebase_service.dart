import 'package:firebase_core/firebase_core.dart';

class FirebaseService {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _initialized = true;
  }
}
