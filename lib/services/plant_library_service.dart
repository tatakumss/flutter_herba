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

  PlantItem({
    required this.name,
    required this.category,
    required this.description,
    required this.uses,
    required this.tags,
    required this.color,
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
    );
  }
}

class PlantLibraryService {
  Future<List<PlantItem>> load() async {
    final raw = await rootBundle.loadString('assets/plants.json');
    final List<dynamic> list = json.decode(raw) as List<dynamic>;
    return list.map((e) => PlantItem.fromJson(e as Map<String, dynamic>)).toList();
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
