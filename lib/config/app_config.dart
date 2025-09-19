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
  static const String defaultUserTitle = "Nature Explorer 🌱";
}
