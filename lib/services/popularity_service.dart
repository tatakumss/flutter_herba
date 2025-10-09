import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PopularityService {
  static const _prefix = 'popularity:'; // key = popularity:<dataset>

  Future<Map<String, int>> _loadMap(String dataset) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$dataset';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <String, int>{};
    try {
      final Map<String, dynamic> m = json.decode(raw);
      return m.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _saveMap(String dataset, Map<String, int> m) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$dataset';
    await prefs.setString(key, json.encode(m));
  }

  Future<void> increment(String dataset, String plantName) async {
    final m = await _loadMap(dataset);
    m[plantName] = (m[plantName] ?? 0) + 1;
    await _saveMap(dataset, m);
  }

  Future<List<String>> topNames(String dataset, {int limit = 10}) async {
    final m = await _loadMap(dataset);
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }

  Future<void> clear(String dataset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$dataset');
  }
}
