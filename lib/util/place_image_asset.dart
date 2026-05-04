import 'package:flutter/services.dart';

/// When the image filename differs slightly from the Firestore / UI place name.
const Map<String, String> _kPlaceImageStemAliases = {
  // DB-friendly spelling → actual file stem under `images/`
  'Quba Mosque': 'Quba Mousque',
};

/// Lowercase kebab stem, e.g. "The Battle of Uhud" → "the-battle-of-uhud" (matches `the-battle-of-uhud.png`).
String _slugStem(String input) {
  var s = input.trim().toLowerCase();
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  s = s.replaceAll(RegExp(r'-+'), '-');
  return s.replaceAll(RegExp(r'^-|-$'), '');
}

/// Returns an asset path like `images/<Name>.jpeg` if it exists in the app bundle.
///
/// Tries, in order: exact [placeName], optional [alias], then a kebab-case slug of [placeName]
/// (so titles like "The Battle of Uhud" can match `images/the-battle-of-uhud.png`).
Future<String?> resolvePlaceImageAsset(String placeName) async {
  final n = placeName.trim();
  if (n.isEmpty) return null;

  final stems = <String>[];
  void addStem(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (!stems.contains(t)) stems.add(t);
  }

  addStem(n);
  final alias = _kPlaceImageStemAliases[n];
  if (alias != null) addStem(alias);
  final slug = _slugStem(n);
  if (slug.isNotEmpty) addStem(slug);

  for (final stem in stems) {
    for (final ext in const ['.jpeg', '.jpg', '.png']) {
      final path = 'images/$stem$ext';
      try {
        await rootBundle.load(path);
        return path;
      } catch (_) {
        continue;
      }
    }
  }
  return null;
}
