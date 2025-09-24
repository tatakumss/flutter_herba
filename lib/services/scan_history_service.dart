import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ScanEntry {
  final String name;
  final double confidence; // 0.0 - 1.0
  final DateTime timestamp;
  final bool success;
  final List<Map<String, dynamic>> candidates; // [{label:String, score:double}, ...]

  ScanEntry({
    required this.name,
    required this.confidence,
    required this.timestamp,
    required this.success,
    required this.candidates,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'success': success,
        'candidates': candidates,
      };

  factory ScanEntry.fromJson(Map<String, dynamic> json) => ScanEntry(
        name: json['name'] as String? ?? 'Unknown',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
        success: json['success'] as bool? ?? false,
        candidates: () {
          final raw = json['candidates'];
          if (raw is List) {
            return raw.map<Map<String, dynamic>>((e) {
              if (e is Map) {
                final label = (e['label'] ?? '').toString();
                final score = (e['score'] is num) ? (e['score'] as num).toDouble() : 0.0;
                return {'label': label, 'score': score};
              }
              return {'label': '', 'score': 0.0};
            }).toList();
          }
          // Backward compatibility: if candidates missing, synthesize from name/confidence
          return [
            {'label': (json['name'] ?? 'Unknown').toString(), 'score': (json['confidence'] as num?)?.toDouble() ?? 0.0},
          ];
        }(),
      );
}

class ScanHistoryService {
  static const _prefsKey = 'scan_history_v1';

  Future<List<ScanEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? <String>[];
    return raw
        .map((s) {
          try {
            return ScanEntry.fromJson(json.decode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanEntry>()
        .toList()
        .reversed
        .toList();
  }

  Future<void> add(ScanEntry entry, {int maxItems = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsKey) ?? <String>[];
    list.add(json.encode(entry.toJson()));
    // Cap the list size by trimming the oldest
    final keep = list.length > maxItems ? list.sublist(list.length - maxItems) : list;
    await prefs.setStringList(_prefsKey, keep);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
