// ignore_for_file: deprecated_member_use, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'dart:convert';
import '../config/app_config.dart';
import 'plant_screen.dart';
import '../services/plant_library_service.dart';
import 'plant_detail_screen.dart';
import '../services/collection_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Text(
                "Discover Nature",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: (Theme.of(context).brightness == Brightness.dark)
                      ? const Color(0xFF81C784)
                      : AppConfig.primaryDark,
                ),
              ),
              const SizedBox(height: 32),

              // Spacer between header and hero
              const SizedBox(height: 8),

              // Hero Card
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
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Plant Identifier",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Scan any plant instantly",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => PlantScreen()),
                        );
                        // Rebuild to re-trigger FutureBuilder and fetch latest collections
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, size: 20),
                          const SizedBox(width: 8),
                          Text("Start Scanning"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // How to scan (compact tips)
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: const Icon(Icons.help_outline, color: Color(0xFF2E7D32)),
                    title: const Text('How to scan', style: TextStyle(fontWeight: FontWeight.w700)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _buildTip(context, 'Fill the frame with the leaf/plant. Avoid background clutter.'),
                      _buildTip(context, 'Good light. Avoid harsh glare and heavy shadows.'),
                      _buildTip(context, 'Hold steady and ensure the subject is in focus.'),
                      _buildTip(context, 'Keep hands and faces out of the frame to avoid Unknown.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Collections Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "My Collections",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: (Theme.of(context).brightness == Brightness.dark)
                          ? const Color(0xFF81C784)
                          : AppConfig.primaryDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to full collections screen
                      // You can implement this later
                    },
                    child: Text(
                      "View All",
                      style: TextStyle(
                        color: AppConfig.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: CollectionService().getCollections(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 140,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  
                  final collections = snapshot.data ?? [];
                  
                  if (collections.isEmpty) {
                    return Container(
                      height: 140,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.2),
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.collections_outlined,
                            size: 32,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "No collections yet",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Start scanning plants to build your collection",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: collections.length > 5 ? 5 : collections.length, // Show max 5 items
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final collection = collections[index];
                        return _buildCollectionCard(context, collection);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Most Searched Herbal Plants
              Text(
                "Most Searched Herbal Plants",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: (Theme.of(context).brightness == Brightness.dark)
                      ? const Color(0xFF81C784)
                      : AppConfig.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<PlantItem>>(
                future: PlantLibraryService().load(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final all = snapshot.data ?? [];
                  final herbs = all.where((p) => p.category.toLowerCase() == 'herb').toList()
                    ..sort((a, b) => a.name.compareTo(b.name));
                  final top = herbs.take(8).toList();
                  if (top.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Library is empty. Add items to assets/plants.json.',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: top.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final p = top[i];
                        return _buildPlantChipCard(context, p);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlantChipCard(BuildContext context, PlantItem p) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: p)),
      ),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.local_florist, color: p.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.category,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionCard(BuildContext context, Map<String, dynamic> collection) {
    // Fields come from CollectionService.getCollections():
    // plantName, imageUrl, imageData, plantInfo (map), isFavorite
    final info = (collection['plantInfo'] as Map<String, dynamic>?) ?? {};
    final name = (collection['plantName']?.toString() ?? 'Unknown').trim().isNotEmpty
        ? collection['plantName'].toString()
        : 'Unknown';
    final confidence = (info['confidence'] is num) ? (info['confidence'] as num).toDouble() : 0.0;
    final isOod = (info['isOod'] as bool?) ?? false;
    
    return InkWell(
      onTap: () => _showCollectionDetail(context, collection),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background: show imageUrl, else base64 imageData, else placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: () {
                final url = collection['imageUrl'] as String?;
                final data = collection['imageData'] as String?;
                if (url != null && url.isNotEmpty) {
                  return Image.network(
                    url, 
                    key: ValueKey('${collection['id']}_${url.hashCode}'),
                    fit: BoxFit.cover, 
                    width: double.infinity, 
                    height: double.infinity
                  );
                } else if (data != null && data.isNotEmpty) {
                  try {
                    final bytes = base64Decode(data);
                    return Image.memory(
                      bytes, 
                      key: ValueKey('${collection['id']}_${data.hashCode}'),
                      fit: BoxFit.cover, 
                      width: double.infinity, 
                      height: double.infinity
                    );
                  } catch (_) {
                    // fall back to placeholder
                  }
                }
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: AppConfig.primaryColor.withValues(alpha: 0.12),
                  child: Icon(Icons.local_florist, color: AppConfig.primaryColor, size: 32),
                );
              }(),
            ),
            
            // Overlay with gradient and content
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            
            // Content overlay
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOod ? Colors.orange : Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOod ? 'Unknown' : '${(confidence * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Plant name
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCollectionDetail(BuildContext context, Map<String, dynamic> collection) {
    final info = (collection['plantInfo'] as Map<String, dynamic>?) ?? {};
    final name = (collection['plantName']?.toString() ?? 'Unknown').trim().isNotEmpty
        ? collection['plantName'].toString()
        : 'Unknown';
    final confidence = (info['confidence'] is num) ? (info['confidence'] as num).toDouble() : 0.0;
    final isOod = (info['isOod'] as bool?) ?? false;
    final scanDate = collection['scanDate'] as String? ?? 'Unknown date';
    final candidates = (info['candidates'] as List?) ?? [];
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Header with back and delete buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppConfig.primaryColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          'Collection Details',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeFromCollection(context, collection),
                        icon: const Icon(Icons.remove_circle, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Container(
                          width: double.infinity,
                          height: 250,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: () {
                              final url = collection['imageUrl'] as String?;
                              final data = collection['imageData'] as String?;
                              if (url != null && url.isNotEmpty) {
                                return Image.network(url, fit: BoxFit.cover);
                              } else if (data != null && data.isNotEmpty) {
                                try {
                                  final bytes = base64Decode(data);
                                  return Image.memory(bytes, fit: BoxFit.cover);
                                } catch (_) {
                                  // fall back to placeholder
                                }
                              }
                              return Container(
                                color: AppConfig.primaryColor.withValues(alpha: 0.12),
                                child: Icon(Icons.local_florist, color: AppConfig.primaryColor, size: 64),
                              );
                            }(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Plant name and status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).textTheme.titleLarge?.color,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isOod ? Colors.orange : Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isOod ? 'Unknown Plant' : '${(confidence * 100).toInt()}% Confidence',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Scan date
                        _buildInfoRow('Scan Date', scanDate),
                        const SizedBox(height: 12),
                        
                        // Confidence details
                        if (!isOod) ...[
                          _buildInfoRow('Confidence Level', '${(confidence * 100).toStringAsFixed(1)}%'),
                          const SizedBox(height: 12),
                        ],
                        
                        // Other candidates
                        if (candidates.isNotEmpty) ...[
                          Text(
                            'Other Possible Matches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.titleMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...candidates.take(3).map((candidate) {
                            final candidateName = candidate['name'] ?? 'Unknown';
                            final candidateConfidence = (candidate['confidence'] as num?)?.toDouble() ?? 0.0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      candidateName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(candidateConfidence * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  void _removeFromCollection(BuildContext context, Map<String, dynamic> collection) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove from Collection'),
          content: Text('Remove "${collection['plantName'] ?? 'this item'}" from your collection?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close confirmation dialog
                Navigator.of(context).pop(); // Close detail dialog
                
                try {
                  // Call collection service to remove from collection
                  final success = await CollectionService().deleteCollection(collection);
                  
                  if (!success) {
                    throw Exception('Failed to remove item');
                  }
                  
                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from collection'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Clear image cache and refresh the collections list
                    imageCache.clear();
                    setState(() {});
                  }
                } catch (e) {
                  // Show error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove from collection: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTip(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, size: 16, color: Color(0xFF66BB6A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.85),
                height: 1.35,
              ),
              ),
          ),
        ],
      ),
    );
  }
}
