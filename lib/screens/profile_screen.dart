// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'edit_profile_screen.dart';
import '../services/profile_local_store.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileLocalStore _localStore = ProfileLocalStore();

  String? _name;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _name = _authService.currentUser?.displayName ?? _authService.currentUser?.email;
    _photoUrl = null;
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    // Load local profile data
    try {
      final local = await _localStore.load();
      if (!mounted) return;
      if (local != null) {
        setState(() {
          if (local['name'] is String && (local['name'] as String).isNotEmpty) {
            _name = local['name'] as String;
          }
          if (local['photoUrl'] is String && (local['photoUrl'] as String).isNotEmpty) {
            _photoUrl = local['photoUrl'] as String;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _openEditProfile() async {
    final user = _authService.currentUser;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          userId: user?.uid ?? '',
          initialName: _name,
          initialPhotoUrl: _photoUrl,
        ),
      ),
    );

    if (result is Map) {
      final name = result['name'];
      final photoUrl = result['photoUrl'];
      if (!mounted) return;
      setState(() {
        if (name is String && name.isNotEmpty) {
          _name = name;
        }
        if (photoUrl is String && photoUrl.isNotEmpty) {
          _photoUrl = photoUrl;
        }
      });
      
      // Persist locally
      await _localStore.save(
        name: _name,
        photoUrl: _photoUrl,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Profile",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openEditProfile,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_outlined,
                        color: AppConfig.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? const [Color(0xFF2E7D32), Color(0xFF1B5E20)]
                        : const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.5)
                          : const Color(0xFF4CAF50).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: AppConfig.primaryColor,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Name
                    Text(
                      _name ?? AppConfig.defaultUserName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Email
                    Text(
                      _authService.currentUser?.email ?? 'No email',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Menu Items
              _buildMenuItem(
                icon: Icons.favorite_outline,
                title: "Favorites",
                subtitle: "Your saved plants",
                color: const Color(0xFFE91E63),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                subtitle: "App preferences",
                color: const Color(0xFF607D8B),
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.info_outline,
                title: "About",
                subtitle: "App information",
                color: const Color(0xFF795548),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
              const SizedBox(height: 32),
              
              // Logout Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await _authService.signOut();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF81C784)
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }
}
