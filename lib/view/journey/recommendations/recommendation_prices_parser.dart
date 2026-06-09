import 'package:flutter/material.dart';

/// Parsed row for nested Firestore `prices` maps (order == 5 special UI).
class RecommendationPriceCategory {
  const RecommendationPriceCategory({
    required this.key,
    required this.label,
    required this.rangeText,
    required this.icon,
  });

  final String key;
  final String label;
  final String rangeText;
  final IconData icon;
}

/// Parses structures like:
/// `{ coffee: { 0: "min = 20 SR", 1: "max = 30 SR" }, ... }`
List<RecommendationPriceCategory> parseRecommendationNestedPrices(Object? raw) {
  if (raw is! Map) return const [];

  final out = <RecommendationPriceCategory>[];
  for (final entry in raw.entries) {
    final catKey = entry.key.toString().trim();
    if (catKey.isEmpty) continue;
    final sub = entry.value;
    if (sub is! Map) continue;

    String? minLine;
    String? maxLine;
    for (final sk in sub.keys) {
      final v = sub[sk]?.toString().trim() ?? '';
      final k = sk.toString();
      if (k == '0' || sk == 0) minLine = v;
      if (k == '1' || sk == 1) maxLine = v;
    }

    final minVal = _firstNumber(minLine);
    final maxVal = _firstNumber(maxLine);
    if (minVal == null && maxVal == null) continue;

    final rangeText = (minVal != null && maxVal != null)
        ? '$minVal–$maxVal SR'
        : (minVal != null)
        ? 'From $minVal SR'
        : 'Up to $maxVal SR';

    out.add(
      RecommendationPriceCategory(
        key: catKey,
        label: _titleCaseCategory(catKey),
        rangeText: rangeText,
        icon: _iconForCategory(catKey),
      ),
    );
  }

  out.sort((a, b) => a.label.compareTo(b.label));
  return out;
}

String? _firstNumber(String? line) {
  if (line == null || line.isEmpty) return null;
  final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(line);
  if (m == null) return null;
  final n = m.group(1)!;
  if (n.endsWith('.0')) return n.substring(0, n.length - 2);
  return n;
}

String _titleCaseCategory(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return raw;
  return s
      .split(RegExp(r'\s+'))
      .map((w) {
        if (w.isEmpty) return w;
        return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
      })
      .join(' ');
}

IconData _iconForCategory(String key) {
  final k = key.toLowerCase();
  if (k.contains('coffee') || k.contains('cafe')) {
    return Icons.local_cafe_outlined;
  }
  if (k.contains('restaurant') || k.contains('dining')) {
    return Icons.restaurant_outlined;
  }
  if (k.contains('snack')) return Icons.cookie_outlined;
  if (k.contains('shop') || k.contains('store')) {
    return Icons.storefront_outlined;
  }
  return Icons.sell_outlined;
}
