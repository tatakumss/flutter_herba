import 'package:flutter/material.dart';
import '../config/app_config.dart';

class HistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> scans = [
    {
      "name": "Rose",
      "confidence": "95%",
      "date": "Today",
      "time": "2:30 PM",
      "status": "success",
      "color": Color(0xFFE91E63)
    },
    {
      "name": "Basil",
      "confidence": "89%",
      "date": "Yesterday",
      "time": "10:15 AM",
      "status": "success",
      "color": Color(0xFF4CAF50)
    },
    {
      "name": "Unknown Plant",
      "confidence": "45%",
      "date": "2 days ago",
      "time": "4:20 PM",
      "status": "failed",
      "color": Color(0xFF9E9E9E)
    },
    {
      "name": "Sunflower",
      "confidence": "92%",
      "date": "3 days ago",
      "time": "11:45 AM",
      "status": "success",
      "color": Color(0xFFFF9800)
    },
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Scan History",
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
                      Icons.filter_list,
                      color: AppConfig.primaryColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // Stats Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Total Scans",
                      "${scans.length}",
                      Icons.camera_alt,
                      const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      "Success Rate",
                      "87%",
                      Icons.check_circle,
                      AppConfig.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // History List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: scans.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final scan = scans[index];
                  return _buildHistoryCard(scan);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConfig.primaryDark,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> scan) {
    final isSuccess = scan["status"] == "success";
    
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
          // Plant Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scan["color"].withOpacity(0.3),
                  scan["color"].withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSuccess ? Icons.local_florist : Icons.help_outline,
              color: scan["color"],
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          
          // Plant Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scan["name"],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.primaryDark,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSuccess 
                            ? const Color(0xFF4CAF50).withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        scan["confidence"],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSuccess ? const Color(0xFF4CAF50) : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${scan['date']} • ${scan['time']}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Action Button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConfig.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppConfig.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
