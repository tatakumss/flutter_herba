import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
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
                      color: AppConfig.primaryDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                ],
              ),
              const SizedBox(height: 32),
              
              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _authService.currentUser?.email ?? AppConfig.defaultUserName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppConfig.defaultUserTitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem("Plants\nScanned", "47"),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildStatItem("Success\nRate", "89%"),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        _buildStatItem("Streak\nDays", "12"),
                      ],
                    ),
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
                icon: Icons.help_outline,
                title: "Help & Support",
                subtitle: "Get assistance",
                color: const Color(0xFF9C27B0),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.settings_outlined,
                title: "Settings",
                subtitle: "App preferences",
                color: const Color(0xFF607D8B),
              ),
              const SizedBox(height: 16),
              _buildMenuItem(
                icon: Icons.info_outline,
                title: "About",
                subtitle: "App information",
                color: const Color(0xFF795548),
              ),
              const SizedBox(height: 32),
              
              // Logout Button
              Container(
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
                      Icon(
                        Icons.logout,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
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
                    fontWeight: FontWeight.bold,
                    color: AppConfig.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey[400],
          ),
        ],
      ),
    );
  }
}
