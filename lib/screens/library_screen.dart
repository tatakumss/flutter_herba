import 'package:flutter/material.dart';
import '../config/app_config.dart';

class LibraryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> plants = [
    {"name": "Rose", "category": "Flower", "color": Color(0xFFE91E63)},
    {"name": "Basil", "category": "Herb", "color": Color(0xFF4CAF50)},
    {"name": "Lavender", "category": "Medicinal", "color": Color(0xFF9C27B0)},
    {"name": "Mint", "category": "Herb", "color": Color(0xFF00BCD4)},
    {"name": "Aloe Vera", "category": "Succulent", "color": Color(0xFF8BC34A)},
    {"name": "Sunflower", "category": "Flower", "color": Color(0xFFFF9800)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Plant Library",
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
                          Icons.search,
                          color: AppConfig.primaryColor,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        Icon(Icons.search, color: Colors.grey[400], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Search plants...",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Icon(Icons.tune, color: Colors.grey[400], size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AppConfig.plantCategories.asMap().entries.map((entry) {
                    int index = entry.key;
                    String category = entry.value;
                    return _buildCategoryChip(category, index == 0);
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Plant Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: plants.length,
                  itemBuilder: (context, index) {
                    final plant = plants[index];
                    return _buildPlantCard(plant);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppConfig.primaryColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppConfig.primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildPlantCard(Map<String, dynamic> plant) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    plant["color"].withOpacity(0.3),
                    plant["color"].withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.local_florist,
                      size: 48,
                      color: plant["color"],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.favorite_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plant["name"],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppConfig.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plant["category"],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: plant["color"].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Learn",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: plant["color"],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
