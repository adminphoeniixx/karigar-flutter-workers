import 'dart:convert';
import 'package:flutter/services.dart';

/// India subset of dr5hn/countries-states-cities-database (ODbL 1.0).
class IndiaLocations {
  static Future<Map<String, List<String>>>? _cached;
  static Future<Map<String, List<String>>> _load() =>
      _cached ??= readBundle(rootBundle).then((data) {
        // A failed/missing asset must not poison the cache for this session.
        if (data.isEmpty) _cached = null;
        return data;
      });

  /// Missing or invalid optional city data falls back to the API reference.
  static Future<Map<String, List<String>>> readBundle(
    AssetBundle bundle,
  ) async {
    try {
      final decoded = jsonDecode(
        await bundle.loadString('assets/data/india_cities.json'),
      );
      if (decoded is! Map<String, dynamic>) return {};
      return decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<List<String>> states() async => (await _load()).keys.toList();
  static Future<List<String>> cities(String state) async {
    final data = await _load();
    for (final entry in data.entries) {
      if (entry.key.toLowerCase() == state.trim().toLowerCase())
        return entry.value;
    }
    return [];
  }

  static List<String> merge(
    Iterable<String> preferred,
    Iterable<String> fallback,
  ) {
    final result = <String, String>{};
    for (final item in [...preferred, ...fallback]) {
      final value = item.trim();
      if (value.isNotEmpty)
        result.putIfAbsent(value.toLowerCase(), () => value);
    }
    return result.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}
