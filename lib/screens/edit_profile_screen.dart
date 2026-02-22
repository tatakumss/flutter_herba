// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../widgets/app_text_field.dart';
import '../utils/snackbar_utils.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialPhotoUrl;

  const EditProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialPhotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  final AuthService _authService = AuthService();
  String? _photoUrl;
  File? _selectedImage;
  bool _uploading = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    // Initialize with existing photo (can be base64 data URL from Firestore)
    _photoUrl = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }


  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      String? finalPhotoUrl = _photoUrl;

      // For Firestore-only: photo is already base64 encoded
      // No need for Firebase Storage upload
      if (_selectedImage != null && _photoUrl != null && _photoUrl!.startsWith('data:image')) {
        // Photo is already in base64 format, ready for Firestore
        finalPhotoUrl = _photoUrl;
      }

      // Update profile in Firestore via AuthService
      await _authService.updateUserProfile(
        displayName: name,
        photoUrl: finalPhotoUrl,
      );

      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Profile updated successfully!');

        Navigator.pop(context, {
          'name': name,
          'photoUrl': finalPhotoUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Failed to update profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_picking || _uploading) return; // prevent re-entrancy / double taps
    
    setState(() { _picking = true; });
    
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 512,  // Smaller for Firestore storage
        maxHeight: 512, // Square aspect ratio
        imageQuality: 70  // Lower quality for smaller base64 size
      );
      if (picked == null) return;
      
      // Convert image to base64
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Store base64 data instead of file
      setState(() {
        _selectedImage = File(picked.path);  // For local preview
        _photoUrl = 'data:image/jpeg;base64,$base64Image';  // Base64 data URL
      });

      SnackBarUtils.showInfo(context, 'Image selected. Click Save to upload.');
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, 'Failed to pick photo: $e');
    } finally {
      if (mounted) {
        setState(() { 
          _picking = false;
        });
      }
    }
  }

  // Appwrite storage upload method removed - no cloud storage available

  Future<void> _showChangePasswordDialog() async {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    bool obscureCurrentPassword = true;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: AppConfig.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Change Password'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your current password and choose a new one.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    
                    // Current Password Field
                    AppTextField.simple(
                      controller: currentPasswordController,
                      label: 'Current Password',
                      obscureText: obscureCurrentPassword,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // New Password Field
                    AppTextField.simple(
                      controller: newPasswordController,
                      label: 'New Password',
                      obscureText: obscureNewPassword,
                      isRequired: true,
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    AppTextField.simple(
                      controller: confirmPasswordController,
                      label: 'Confirm New Password',
                      obscureText: obscureConfirmPassword,
                      isRequired: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _changePassword(
                      context,
                      currentPasswordController.text,
                      newPasswordController.text,
                      confirmPasswordController.text,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changePassword(
    BuildContext context,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    // Validation
    if (currentPassword.isEmpty) {
      SnackBarUtils.showWarning(context, 'Please enter your current password');
      return;
    }

    if (newPassword.isEmpty) {
      SnackBarUtils.showWarning(context, 'Please enter a new password');
      return;
    }

    if (newPassword.length < 6) {
      SnackBarUtils.showError(context, 'New password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      SnackBarUtils.showError(context, 'New passwords do not match');
      return;
    }

    if (currentPassword == newPassword) {
      SnackBarUtils.showWarning(context, 'New password must be different from current password');
      return;
    }

    try {
      await _authService.changePassword(currentPassword, newPassword);
      
      Navigator.of(context).pop(); // Close dialog
      
      SnackBarUtils.showSuccess(context, 'Password changed successfully!');
    } catch (e) {
      SnackBarUtils.showError(context, e.toString());
    }
  }

  // Helper method to get appropriate ImageProvider for different image types
  ImageProvider? _getProfileImage() {
    if (_photoUrl == null || _photoUrl!.isEmpty) return null;
    
    // Handle base64 data URLs
    if (_photoUrl!.startsWith('data:image')) {
      final base64String = _photoUrl!.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    }
    
    // Handle local file paths (during selection)
    if (_photoUrl!.startsWith('/')) {
      return FileImage(File(_photoUrl!));
    }
    
    // Handle network URLs (fallback)
    return NetworkImage(_photoUrl!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar (with upload)
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: _getProfileImage(),
                    child: _photoUrl == null || _photoUrl!.isEmpty
                        ? const Icon(Icons.person, size: 48, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: (_uploading || _picking) ? null : _pickAndUploadAvatar,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppConfig.primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(6),
                        child: (_uploading || _picking)
                            ? const SizedBox(
                                height: 18, 
                                width: 18, 
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, 
                                  color: Colors.white
                                )
                              )
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            Text(
              'Name', 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold
              )
            ),
            const SizedBox(height: 8),
            AppTextField.simple(
              controller: _nameController,
              hintText: 'Enter your name',
              keyboardType: TextInputType.name,
            ),

            const SizedBox(height: 24),
            
            // Change Password Button
            OutlinedButton.icon(
              onPressed: _showChangePasswordDialog,
              icon: const Icon(Icons.lock_outline),
              label: const Text('Change Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConfig.primaryColor,
                side: BorderSide(color: AppConfig.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConfig.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
