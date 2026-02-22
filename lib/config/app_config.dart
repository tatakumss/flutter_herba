import 'package:flutter/material.dart';

// Configuration class for easy customization
class AppConfig {
  static const String appName = "PediaHerb";
  static const String appDescription = "Plant Identification App";
  
  // Primary Brand Colors
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1B5E20);
  static const Color backgroundColor = Color(0xFFF8FBF8);
  
  // Semantic Colors
  static const Color errorColor = Colors.red;
  static const Color successColor = Colors.green;
  static const Color warningColor = Colors.orange;
  static const Color infoColor = Colors.blue;
  
  // Action Colors
  static const Color deleteColor = Colors.red;
  static const Color confirmColor = Colors.green;
  static const Color cancelColor = Colors.grey;
  
  // Feedback Colors
  static const Color reportErrorColor = Color(0xFFFF7043); // Orange[700]
  static const Color suggestionColor = primaryColor;
  
  // UI Element Colors
  static const Color cardColor = Colors.white;
  static const Color shadowColor = Colors.black;
  static const Color transparentColor = Colors.transparent;
  
  // Text Colors (Light Theme)
  static const Color textPrimaryLight = primaryDark;
  static const Color textSecondaryLight = Color(0xFF666666);
  
  // Text Colors (Dark Theme)
  static const Color textPrimaryDark = Colors.white;
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  
  // Helper Methods for Theme-Aware Colors
  static Color getTextPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color getTextSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color getCardColor(bool isDark) => isDark ? Colors.grey[800]! : cardColor;
  static Color getShadowColor(bool isDark) => shadowColor.withOpacity(isDark ? 0.3 : 0.1);
  
  // Helper method for title colors (reduces duplicate theme logic)
  static Color getTitleColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF81C784) : primaryDark;
  }
  
  // Opacity Variants
  static Color getPrimaryWithOpacity(double opacity) => primaryColor.withOpacity(opacity);
  static Color getErrorWithOpacity(double opacity) => errorColor.withOpacity(opacity);
  static Color getSuccessWithOpacity(double opacity) => successColor.withOpacity(opacity);
  static Color getWarningWithOpacity(double opacity) => warningColor.withOpacity(opacity);
  
  // Plant categories - easily customizable
  static const List<String> plantCategories = [
    "All", "Herbs", "Flowers", "Medicinal", "Succulents"
  ];
  
  // User profile settings
  static const String defaultUserName = "Plant Enthusiast";
  static const String defaultUserTitle = "Nature Lover 🌱";
  
}
