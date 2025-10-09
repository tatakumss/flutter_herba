import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';

enum PlantDataset { mini, kaggle }

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
  Future<List<PlantItem>> load({PlantDataset source = PlantDataset.mini}) async {
    // Prefer building from AssetManifest for requested dataset if assets are present.
    final manifestItems = await _tryLoadFromAssetManifest(source: source);
    if (manifestItems != null && manifestItems.isNotEmpty) {
      return manifestItems;
    }

    // Optionally fallback to plants.json if it exists
    dynamic decoded;
    try {
      final raw = await rootBundle.loadString('assets/plants.json');
      decoded = json.decode(raw);
    } catch (_) {
      decoded = null;
    }

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
        if (path.startsWith('mini_dataset/')) return 'assets/images/$path';
        if (path.startsWith('images/')) return 'assets/$path';
        return 'assets/images/$path';
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

  Future<List<PlantItem>?> _tryLoadFromAssetManifest({PlantDataset source = PlantDataset.mini}) async {
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = (json.decode(manifestRaw) as Map).cast<String, dynamic>();
      final String prefix = source == PlantDataset.kaggle
          ? 'assets/images/kaggle_dataset/'
          : 'assets/images/mini_dataset/';
      final keys = manifest.keys.where((k) => k.startsWith(prefix)).toList();
      if (keys.isEmpty) return null;

      // Optional metadata: base + dataset-specific override (kaggle)
      Map<String, dynamic> meta = const {};
      try {
        final metaRaw = await rootBundle.loadString('assets/plant_metadata.json');
        meta = (json.decode(metaRaw) as Map).cast<String, dynamic>();
      } catch (_) {}
      if (source == PlantDataset.kaggle) {
        try {
          final kRaw = await rootBundle.loadString('assets/kaggle_metadata.json');
          final Map<String, dynamic> kMeta = (json.decode(kRaw) as Map).cast<String, dynamic>();
          // merge override: kaggle entries overwrite base entries
          meta = {...meta, ...kMeta};
        } catch (_) {}
      }

      // Build a normalized lookup to better match kaggle class folder names
      String normKey(String s) => s
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .replaceAll('(', ' ')
          .replaceAll(')', ' ')
          .replaceAll(RegExp(r"[^a-z0-9 ]"), '')
          .replaceAll(RegExp(r"\s+"), ' ')
          .replaceAll(' ', '') // remove spaces so "aloe vera" == "aloevera"
          .trim();
      final Map<String, Map<String, dynamic>> metaNorm = {};
      final Map<String, String> metaKeyByNorm = {};
      for (final entry in meta.entries) {
        final k = normKey(entry.key);
        metaNorm[k] = (entry.value as Map).cast<String, dynamic>();
        metaKeyByNorm[k] = entry.key; // preserve canonical display key (e.g., "Aloe Vera")
      }

      // Aliases to fix common dataset naming mismatches
      final Map<String, String> alias = {
        'alovera': 'aloevera',
        'aloevera': 'aloevera',
        'chilly': 'chili',
        'pomoegranate': 'pomegranate',
      };

      String prettifyName(String s) {
        // Replace underscores and normalize spacing, then Title Case
        final cleaned = s.replaceAll('_', ' ').replaceAll(RegExp(r"\s+"), ' ').trim();
        return cleaned.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + (w.length > 1 ? w.substring(1).toLowerCase() : ''))).join(' ');
      }

      Color colorFor(String name) {
        final h = name.codeUnits.fold<int>(0, (a, b) => (a * 131 + b) & 0xFFFFFFFF);
        final r = 0x40 + (h & 0x3F);
        final g = 0x80 + ((h >> 6) & 0x3F);
        final b = 0x40 + ((h >> 12) & 0x3F);
        return Color(0xFF000000 | (r << 16) | (g << 8) | b);
      }

      // Group assets by class folder: assets/images/{dataset}/<Class>/...
      final Map<String, List<String>> grouped = {};
      for (final path in keys) {
        final parts = path.split('/');
        if (parts.length < 5) continue; // assets / images / {dataset} / <Class> / <file>
        final className = parts[3]; // index 3 is the <Class>
        // Skip non_herbal bucket if present
        if (className.toLowerCase() == 'non_herbal') continue;
        grouped.putIfAbsent(className, () => []).add(path);
      }

      final items = <PlantItem>[];
      grouped.forEach((name, paths) {
        String key = normKey(name);
        key = alias[key] ?? key;
        final metaEntry = meta[key] is Map ? (meta[key] as Map?) : metaNorm[key];
        final desc = metaEntry == null ? ' ' : (metaEntry['description'] ?? ' ').toString();
        final uses = ((metaEntry?['uses'] as List?) ?? const []).map((e) => e.toString()).toList();
        assert(() {
          if (metaEntry == null) {
            // ignore: avoid_print
            print('[LibraryDebug] No metadata for class: $name (norm: $key)');
          }
          return true;
        }());
        final displayName = metaKeyByNorm[key] ?? prettifyName(name);
        items.add(PlantItem(
          name: displayName,
          category: '', // omit category label in UI
          description: desc,
          uses: uses,
          tags: const [],
          color: colorFor(name),
          assetImages: paths..sort(),
        ));
      });

      // Sort by name for consistency
      items.sort((a, b) => a.name.compareTo(b.name));
      return items;
    } catch (_) {
      return null;
    }
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
