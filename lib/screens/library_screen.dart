// ignore_for_file: deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../config/app_config.dart';
import '../services/plant_library_service.dart';
import 'plant_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _service = PlantLibraryService();
  List<PlantItem> _all = [];
  String _query = '';
  String _selectedCategory = 'Herb';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.load();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
    });
    // DEBUG: verify first asset path exists in asset bundle
    if (_all.isNotEmpty && _all.first.assetImages.isNotEmpty) {
      final testPath = _all.first.assetImages.first;
      // Print the path we will try to load
      // ignore: avoid_print
      print('[LibraryDebug] First asset path: ' + testPath);
      try {
        await rootBundle.load(testPath);
        // ignore: avoid_print
        print('[LibraryDebug] Asset found in bundle: ' + testPath);
      } catch (e) {
        // ignore: avoid_print
        print('[LibraryDebug] Asset NOT found in bundle: ' + testPath + ' -> ' + e.toString());
        // Extra: inspect AssetManifest.json for mini_dataset entries
        try {
          final manifestRaw = await rootBundle.loadString('AssetManifest.json');
          // AssetManifest is a JSON map: assetPath -> [variants]
          final Map<String, dynamic> manifest = (json.decode(manifestRaw) as Map).cast<String, dynamic>();
          final keys = manifest.keys.where((k) => k.startsWith('assets/images/mini_dataset/')).toList()..sort();
          // ignore: avoid_print
          print('[LibraryDebug] Manifest mini_dataset count: ' + keys.length.toString());
          for (var i = 0; i < (keys.length < 5 ? keys.length : 5); i++) {
            // ignore: avoid_print
            print('[LibraryDebug] Sample key ' + i.toString() + ': ' + keys[i]);
          }
          final hasExact = keys.contains(testPath);
          // ignore: avoid_print
          print('[LibraryDebug] Manifest contains exact testPath: ' + hasExact.toString());
        } catch (e2) {
          // ignore: avoid_print
          print('[LibraryDebug] Failed to read AssetManifest.json: ' + e2.toString());
        }
      }
    } else {
      // ignore: avoid_print
      print('[LibraryDebug] No assetImages on first item or list empty');
    }
  }

  List<PlantItem> get _filtered => _service.search(_all, _query, category: _selectedCategory);

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
                          color: (Theme.of(context).brightness == Brightness.dark)
                              ? const Color(0xFF81C784)
                              : AppConfig.primaryDark,
                        ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Search plants...',
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        Icon(Icons.tune, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6), size: 20),
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
                  children: [
                    _buildCategoryChip('Herb', _selectedCategory == 'Herb'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Plant Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          // Make cards a bit taller to avoid bottom overflows
                          childAspectRatio: 0.72,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final plant = _filtered[index];
                          return _buildPlantCard(plant, context);
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
        color: isSelected ? AppConfig.primaryColor : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedCategory = label == 'All' ? '' : label),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
  label,
  style: TextStyle(
    color: isSelected ? Colors.white : AppConfig.primaryColor,
    fontWeight: FontWeight.w600,
    fontSize: 14,
  ),
),
        ),
      ),
    );
  }

  Widget _buildPlantCard(PlantItem plant, BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlantDetailScreen(plant: plant)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (plant.assetImages.isNotEmpty)
                      Image.asset(
                        plant.assetImages.first,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                plant.color.withValues(alpha: 0.3),
                                plant.color.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(child: Icon(Icons.image_not_supported_outlined, color: plant.color)),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              plant.color.withValues(alpha: 0.3),
                              plant.color.withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.local_florist,
                            size: 48,
                            color: plant.color,
                          ),
                        ),
                      ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: (Theme.of(context).brightness == Brightness.dark)
                                ? const Color(0xFF81C784)
                                : AppConfig.primaryDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plant.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: plant.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Learn",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: plant.color,
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
      ),
    );
  }
}
