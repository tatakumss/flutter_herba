import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

class PlantItem {
  final String name;
  final String category;
  final String description;
  final List<String> uses;
  final List<String> tags;
  final Color color;
  final List<String> assetImages;

  PlantItem({
    required this.name,
    required this.category,
    required this.description,
    required this.uses,
    required this.tags,
    required this.color,
    this.assetImages = const [],
  });

  factory PlantItem.fromJson(Map<String, dynamic> json) {
    Color parseColor(String hex) {
      final c = hex.replaceFirst('#', '');
      return Color(int.parse('FF$c', radix: 16));
    }

    return PlantItem(
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? 'Other').toString(),
      description: (json['description'] ?? '').toString(),
      uses: ((json['uses'] as List?) ?? const []).map((e) => e.toString()).toList(),
      tags: ((json['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      color: parseColor((json['color'] ?? '#4CAF50').toString()),
      assetImages: ((json['assetImages'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class PlantLibraryService {
  Future<List<PlantItem>> load() async {
    final raw = await rootBundle.loadString('assets/plants.json');
    final decoded = json.decode(raw);

    // Case 1: original schema: List<Map<String,dynamic>>
    if (decoded is List) {
      return decoded.map<PlantItem>((e) => PlantItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    }

    // Case 2: new schema: Map<className, List<paths>>
    if (decoded is Map) {
      final Map<String, dynamic> m = decoded.cast<String, dynamic>();

      Color colorFor(String name) {
        final h = name.codeUnits.fold<int>(0, (a, b) => (a * 131 + b) & 0xFFFFFFFF);
        final r = 0x40 + (h & 0x3F);
        final g = 0x80 + ((h >> 6) & 0x3F);
        final b = 0x40 + ((h >> 12) & 0x3F);
        return Color(0xFF000000 | (r << 16) | (g << 8) | b);
      }

      String norm(String p) {
        String path = p.replaceAll('\\', '/');
        if (path.startsWith('assets/')) return path;
        if (path.startsWith('mini_dataset/')) return 'assets/images/' + path;
        if (path.startsWith('images/')) return 'assets/' + path;
        return 'assets/images/' + path;
      }

      // Optional metadata: descriptions and uses
      Map<String, dynamic> meta = const {};
      try {
        final metaRaw = await rootBundle.loadString('assets/plant_metadata.json');
        meta = (json.decode(metaRaw) as Map).cast<String, dynamic>();
      } catch (_) {
        // ignore missing metadata file
      }

      final items = <PlantItem>[];
      m.forEach((name, v) {
        final List<String> imgs = (v as List? ?? const []).map((e) => norm(e.toString())).toList();
        final metaEntry = meta[name] as Map?;
        final desc = metaEntry == null ? ' ' : (metaEntry['description'] ?? ' ').toString();
        final uses = ((metaEntry?['uses'] as List?) ?? const []).map((e) => e.toString()).toList();
        items.add(PlantItem(
          name: name,
          category: 'Herb',
          description: desc,
          uses: uses,
          tags: const [],
          color: colorFor(name),
          assetImages: imgs,
        ));
      });
      return items;
    }

    // Fallback
    return const <PlantItem>[];
  }

  List<PlantItem> search(List<PlantItem> all, String query, {String? category}) {
    final q = query.trim().toLowerCase();
    return all.where((p) {
      final inCat = category == null || category.isEmpty || p.category.toLowerCase() == category.toLowerCase();
      if (!inCat) return false;
      if (q.isEmpty) return true;
      final hay = '${p.name} ${p.category} ${p.description} ${p.tags.join(' ')} ${p.uses.join(' ')}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }
}
