import 'package:flutter/material.dart';
import '../config/app_config.dart';

class PlantScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Plant Scanner",
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
                      Icons.help_outline,
                      color: AppConfig.primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Camera Preview Area
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4CAF50).withOpacity(0.1),
                      const Color(0xFF2E7D32).withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 64,
                              color: AppConfig.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Position plant in frame",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppConfig.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Make sure the plant is well-lit\nand clearly visible",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Corner guides
                    Positioned(
                      top: 20,
                      left: 20,
                      child: _buildCornerGuide(true, true),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: _buildCornerGuide(true, false),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: _buildCornerGuide(false, true),
                    ),
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: _buildCornerGuide(false, false),
                    ),
                  ],
                ),
              ),
            ),
            
            // Action Buttons
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Primary Action - Camera
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              "Capture Plant",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Secondary Actions Row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: () {},
                              icon: Icon(
                                Icons.photo_library_outlined,
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              label: Text(
                                "Gallery",
                                style: TextStyle(
                                  color: AppConfig.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextButton.icon(
                              onPressed: () {},
                              icon: Icon(
                                Icons.flash_on_outlined,
                                color: AppConfig.primaryColor,
                                size: 20,
                              ),
                              label: Text(
                                "Flash",
                                style: TextStyle(
                                  color: AppConfig.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCornerGuide(bool isTop, bool isLeft) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          left: isLeft ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
          right: !isLeft ? BorderSide(color: const Color(0xFF4CAF50), width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
