import 'package:appwrite/appwrite.dart';
import '../config/app_config.dart';

class AppwriteService {
  static late Client _client;
  static late Account _account;
  static late Databases _databases;
  static late Storage _storage;

  // Singleton pattern
  static final AppwriteService _instance = AppwriteService._internal();
  factory AppwriteService() => _instance;
  AppwriteService._internal();

  static void initialize() {
    _client = Client()
        .setEndpoint(Environment.appwritePublicEndpoint)
        .setProject(Environment.appwriteProjectId)
        .setSelfSigned(status: false) // Explicitly set to false for production
        .addHeader('X-Appwrite-Response-Format', '1.4.0'); // Add API version header

    _account = Account(_client);
    _databases = Databases(_client);
    _storage = Storage(_client);
  }

  // Getters for services
  static Account get account => _account;
  static Databases get databases => _databases;
  static Storage get storage => _storage;
  static Client get client => _client;
}
