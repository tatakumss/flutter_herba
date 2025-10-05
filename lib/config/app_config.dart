import 'package:flutter/material.dart';

// Configuration class for easy customization
class AppConfig {
  static const String appName = "PediaHerb";
  static const String appDescription = "Plant Identification App";
  
  // Colors
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color backgroundColor = Color(0xFFF8FBF8);
  
  // Plant categories - easily customizable
  static const List<String> plantCategories = [
    "All", "Herbs", "Flowers", "Medicinal", "Succulents"
  ];
  
  // User profile settings
  static const String defaultUserName = "Plant Enthusiast";
  static const String defaultUserTitle = "Nature Lover 🌱";
  
  // Appwrite Configuration
  static const String appwriteDatabaseId = 'pediaherb_db'; // Database ID
  static const String appwriteStorageBucketId = 'profile_photos'; // Storage bucket ID
  static const String scansBucketId = 'scans'; // Storage bucket for saved scans
  
  // Collection IDs
  static const String usersCollectionId = 'users';
  static const String scansCollectionId = 'scans';
  static const String feedbackCollectionId = 'feedback';
  static const String reportsCollectionId = 'reports';
}

class Environment {
  static const String appwriteProjectId = '68d4f15b002baad3b7f6';
  static const String appwriteProjectName = 'sample';
  static const String appwritePublicEndpoint = 'https://nyc.cloud.appwrite.io/v1';
}
