// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/collection_service.dart';
import '../utils/snackbar_utils.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final CollectionService _collectionService = CollectionService();
  
  UserProfile? _userProfile;
  bool _loading = true;
  int _collectionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getUserProfile();
      final collections = await _collectionService.getCollections();
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _collectionsCount = collections.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditProfile() async {
    final user = _authService.currentUser;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userId: user?.uid ?? '',
          initialName: _userProfile?.displayName ?? _authService.currentUser?.displayName,
          initialPhotoUrl: _userProfile?.photoUrl,
        ),
      ),
    );

    if (result is Map) {
      final name = result['name'];
      final photoUrl = result['photoUrl'];
      if (!mounted) return;
      
      // Update profile in Firestore
      try {
        await _authService.updateUserProfile(
          displayName: name as String?,
          photoUrl: photoUrl as String?,
        );
        // Reload profile data
        await _loadUserProfile();
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(context, 'Failed to update profile: $e');
        }
      }
    }
  }

  // Helper method to get appropriate ImageProvider for different image types
  ImageProvider? _getProfileImage() {
    final photoUrl = _userProfile?.photoUrl;
    if (photoUrl == null || photoUrl.isEmpty) return null;
    
    // Handle base64 data URLs
    if (photoUrl.startsWith('data:image')) {
      final base64String = photoUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    }
    
    // Handle local file paths (shouldn't happen in profile screen, but for safety)
    if (photoUrl.startsWith('/')) {
      return FileImage(File(photoUrl));
    }
    
    // Handle network URLs (fallback)
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_loading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [const Color(0xFF37353E), const Color(0xFF2F2D36)]
                  : [const Color(0xFFF8FBF8), const Color(0xFFE8F5E8)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF37353E), const Color(0xFF2F2D36)]
                : [const Color(0xFFF8FBF8), const Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // Modern Header with floating profile
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    children: [
                      // Top bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Profile",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppConfig.primaryDark,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConfig.getShadowColor(isDark),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _openEditProfile,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    color: AppConfig.primaryColor,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      
                      // Modern Profile Card
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppConfig.getShadowColor(isDark),
                              blurRadius: 30,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            
                            // Profile Image with modern styling
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppConfig.primaryColor.withOpacity(0.1),
                                    AppConfig.primaryColor.withOpacity(0.3),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConfig.primaryColor.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.transparent,
                                backgroundImage: _getProfileImage(),
                                child: _userProfile?.photoUrl == null
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 60,
                                        color: AppConfig.primaryColor,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Name with modern typography
                            Text(
                              _userProfile?.displayName ?? _authService.currentUser?.displayName ?? AppConfig.defaultUserName,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppConfig.primaryDark,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            
                            // Email with subtle styling
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withOpacity(0.05) : AppConfig.primaryColor.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _authService.currentUser?.email ?? 'No email',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white.withOpacity(0.7) : AppConfig.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Statistics Card
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Center(
                                child: SizedBox(
                                  width: 200,
                                  child: _buildStatCard(
                                    icon: Icons.collections_bookmark_rounded,
                                    title: "Collections",
                                    value: _collectionsCount.toString(),
                                    color: const Color(0xFF4CAF50),
                                    isDark: isDark,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Modern Menu Items
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildModernMenuItem(
                        icon: Icons.settings_rounded,
                        title: "Settings",
                        subtitle: "App preferences & customization",
                        color: const Color(0xFF607D8B),
                        isDark: isDark,
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                      const SizedBox(height: 16),
                      const SizedBox(height: 32),
                      
                      // Sign Out Button (Capture Plant Style - Medium)
                      SizedBox(
                        width: 200, // Medium width instead of full width
                        child: ElevatedButton(
                          onPressed: () async {
                            await _showLogoutDialog();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConfig.deleteColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14), // Slightly smaller than original 18
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, size: 20, color: Colors.white), // Smaller icon for medium size
                              const SizedBox(width: 10), // Smaller spacing
                              Text(
                                "Sign Out",
                                style: TextStyle(
                                  fontSize: 16, // Smaller font for medium size
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withOpacity(0.7) : color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppConfig.getShadowColor(isDark),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppConfig.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppConfig.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppConfig.getTextSecondary(isDark).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppConfig.getTextSecondary(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(
          'Are you sure you want to sign out of your account?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppConfig.cancelColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.deleteColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _authService.signOut();
    }
  }
}
