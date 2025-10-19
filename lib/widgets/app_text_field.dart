import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// A comprehensive reusable text field component that supports multiple styles
/// and configurations for consistent UI across the PediaHerb app.
class AppTextField extends StatelessWidget {
  /// The text controller for the field
  final TextEditingController controller;
  
  /// The label text displayed above/in the field
  final String? label;
  
  /// The hint text displayed when field is empty
  final String? hintText;
  
  /// The prefix icon displayed at the start of the field
  final IconData? prefixIcon;
  
  /// The suffix widget displayed at the end of the field
  final Widget? suffixIcon;
  
  /// The keyboard type for the field
  final TextInputType? keyboardType;
  
  /// Whether the text should be obscured (for passwords)
  final bool obscureText;
  
  /// Whether the field is enabled
  final bool enabled;
  
  /// The maximum number of lines
  final int? maxLines;
  
  /// The maximum length of text
  final int? maxLength;
  
  /// The validation function
  final String? Function(String?)? validator;
  
  /// The callback when text changes
  final void Function(String)? onChanged;
  
  /// The callback when field is submitted
  final void Function(String)? onSubmitted;
  
  /// The style variant of the text field
  final AppTextFieldStyle style;
  
  /// Whether to show the character counter
  final bool showCounter;
  
  /// Custom border radius
  final double? borderRadius;
  
  /// Whether the field is required (shows * in label)
  final bool isRequired;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.style = AppTextFieldStyle.modern,
    this.showCounter = true,
    this.borderRadius,
    this.isRequired = false,
  });

  /// Factory constructor for modern auth fields with full styling
  factory AppTextField.auth({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      prefixIcon: prefixIcon,
      keyboardType: keyboardType,
      obscureText: obscureText,
      suffixIcon: suffixIcon,
      validator: validator,
      style: AppTextFieldStyle.modern,
      isRequired: isRequired,
    );
  }

  /// Factory constructor for search fields
  factory AppTextField.search({
    required TextEditingController controller,
    String hintText = 'Search...',
    void Function(String)? onChanged,
    void Function(String)? onSubmitted,
  }) {
    return AppTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: Icons.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTextFieldStyle.search,
    );
  }

  /// Factory constructor for multiline feedback/comment fields
  factory AppTextField.multiline({
    required TextEditingController controller,
    String? label,
    String? hintText,
    int maxLines = 4,
    int? maxLength = 500,
    String? Function(String?)? validator,
    bool showCounter = false,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      style: AppTextFieldStyle.multiline,
      showCounter: showCounter,
    );
  }

  /// Factory constructor for simple profile/form fields
  factory AppTextField.simple({
    required TextEditingController controller,
    String? label,
    String? hintText,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool isRequired = false,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hintText: hintText,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: AppTextFieldStyle.simple,
      isRequired: isRequired,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return _buildTextField(context, isDark);
  }

  Widget _buildTextField(BuildContext context, bool isDark) {
    switch (style) {
      case AppTextFieldStyle.modern:
        return _buildModernTextField(isDark);
      case AppTextFieldStyle.search:
        return _buildSearchTextField(isDark);
      case AppTextFieldStyle.multiline:
        return _buildMultilineTextField(isDark);
      case AppTextFieldStyle.simple:
        return _buildSimpleTextField(isDark);
    }
  }

  Widget _buildModernTextField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppConfig.getCardColor(isDark),
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        border: Border.all(
          color: AppConfig.getTextSecondary(isDark).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        enabled: enabled,
        maxLines: maxLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        style: TextStyle(
          color: AppConfig.getTextPrimary(isDark),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: isRequired && label != null ? '$label *' : label,
          hintText: hintText,
          labelStyle: TextStyle(
            color: AppConfig.getTextSecondary(isDark),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: AppConfig.getTextSecondary(isDark).withOpacity(0.7),
          ),
          floatingLabelStyle: TextStyle(
            color: AppConfig.primaryColor,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: prefixIcon != null ? Container(
            margin: const EdgeInsets.only(right: 12),
            child: Icon(
              prefixIcon,
              color: AppConfig.primaryColor,
              size: 22,
            ),
          ) : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            borderSide: BorderSide(
              color: AppConfig.primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            borderSide: BorderSide(
              color: AppConfig.errorColor,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            borderSide: BorderSide(
              color: AppConfig.errorColor,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          counterText: showCounter ? null : '',
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildSearchTextField(bool isDark) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      style: TextStyle(
        color: AppConfig.getTextPrimary(isDark),
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppConfig.getTextSecondary(isDark),
        ),
        prefixIcon: Icon(
          prefixIcon ?? Icons.search,
          color: AppConfig.getTextSecondary(isDark),
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppConfig.getCardColor(isDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildMultilineTextField(bool isDark) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      enabled: enabled,
      style: TextStyle(
        color: AppConfig.getTextPrimary(isDark),
      ),
      decoration: InputDecoration(
        labelText: isRequired && label != null ? '$label *' : label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: AppConfig.getTextSecondary(isDark),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(
          color: AppConfig.getTextSecondary(isDark).withOpacity(0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          borderSide: BorderSide(
            color: AppConfig.getTextSecondary(isDark).withOpacity(0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          borderSide: BorderSide(
            color: AppConfig.getTextSecondary(isDark).withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
          borderSide: BorderSide(
            color: AppConfig.primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.all(16),
        counterText: showCounter ? null : '',
      ),
    );
  }

  Widget _buildSimpleTextField(bool isDark) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(
        color: AppConfig.getTextPrimary(isDark),
      ),
      decoration: InputDecoration(
        labelText: isRequired && label != null ? '$label *' : label,
        hintText: hintText,
        labelStyle: TextStyle(
          color: AppConfig.getTextSecondary(isDark),
        ),
        hintStyle: TextStyle(
          color: AppConfig.getTextSecondary(isDark).withOpacity(0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
          borderSide: BorderSide(
            color: AppConfig.getTextSecondary(isDark).withOpacity(0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
          borderSide: BorderSide(
            color: AppConfig.primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 8),
          borderSide: BorderSide(
            color: AppConfig.errorColor,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }
}

/// Enum defining different text field styles
enum AppTextFieldStyle {
  /// Modern style with full theming and icons (for auth screens)
  modern,
  
  /// Search style with search icon and filled background
  search,
  
  /// Multiline style for comments and feedback
  multiline,
  
  /// Simple style for basic forms
  simple,
}
