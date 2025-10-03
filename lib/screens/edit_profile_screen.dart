// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;
  final DateTime? initialBirthday;
  final String? initialPhotoUrl;
  final String? initialBio;

  const EditProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.initialBirthday,
    this.initialPhotoUrl,
    this.initialBio,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final AuthService _authService = AuthService();
  DateTime? _birthday;
  String? _photoUrl;
  bool _uploading = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _bioController = TextEditingController(text: widget.initialBio ?? '');
    _birthday = widget.initialBirthday;
    _photoUrl = widget.initialPhotoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final firstDate = DateTime(1900, 1, 1);
    final lastDate = DateTime(now.year, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select birthday',
    );
    if (selected != null) {
      setState(() => _birthday = selected);
    }
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  int _ageFrom(DateTime d) {
    final today = DateTime.now();
    int age = today.year - d.year;
    if (today.month < d.month || (today.month == d.month && today.day < d.day)) {
      age--;
    }
    return age;
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }
    Navigator.pop(context, {
      'name': name,
      'birthday': _birthday?.toIso8601String(),
      'photoUrl': _photoUrl,
      'bio': _bioController.text.trim(),
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_picking || _uploading) return; // prevent re-entrancy / double taps
    
    setState(() { _picking = true; });
    
    try {
      if (widget.userId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to update your photo.')),
        );
        return;
      }
      
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      if (picked == null) return;
      
      setState(() => _uploading = true);

      // Save locally only (Firebase Storage removed)
      final localPath = await _saveAvatarLocally(picked);
      if (!mounted) return;
      
      setState(() {
        _photoUrl = localPath; // file://...
        _uploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo saved locally')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() { _picking = false; });
      }
    }
  }

  Future<String> _saveAvatarLocally(XFile picked) async {
    final dir = await getApplicationDocumentsDirectory();
    final avatarsDir = Directory('${dir.path}/avatars');
    if (!await avatarsDir.exists()) {
      await avatarsDir.create(recursive: true);
    }
    final file = File('${avatarsDir.path}/profile.jpg');
    await file.writeAsBytes(await picked.readAsBytes(), flush: true);
    return 'file://${file.path}';
  }

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
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrentPassword,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: Icon(Icons.lock_outlined, color: AppConfig.primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrentPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureCurrentPassword = !obscureCurrentPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppConfig.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // New Password Field
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: Icon(Icons.lock_reset, color: AppConfig.primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureNewPassword = !obscureNewPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppConfig.primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Confirm Password Field
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: Icon(Icons.lock_reset, color: AppConfig.primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppConfig.primaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppConfig.primaryColor),
                        ),
                      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your current password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a new password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentPassword == newPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be different from current password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await _authService.changePassword(currentPassword, newPassword);
      
      Navigator.of(context).pop(); // Close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                    backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                    child: _photoUrl == null
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
                          color: Colors.green,
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
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Name
            Text('Name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Enter your name',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),

            const SizedBox(height: 16),

            // Birthday
            Text('Birthday', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickBirthday,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_birthday != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_formatDate(_birthday!)),
                          const SizedBox(height: 2),
                          Text('Age ${_ageFrom(_birthday!)}', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      )
                    else
                      Text('Tap to select your birthday', style: TextStyle(color: Colors.grey.shade600)),
                    const Icon(Icons.cake_outlined)
                  ],
                ),
              ),
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
            FilledButton(
              onPressed: _save,
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
