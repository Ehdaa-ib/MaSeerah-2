import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// When the image filename differs slightly from the Firestore / UI place name.
const Map<String, String> _kPlaceImageStemAliases = {
  // DB-friendly spelling → actual file stem under `images/`
  'Quba Mosque': 'Quba Mousque',
};

// Arabic diacritics commonly found in names; removing them makes matching more robust.
final _arabicDiacritics = RegExp(
  r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
);

/// Normalized key for matching Firestore landmark `name` ↔ image filename stem.
///
/// - case-insensitive
/// - collapses whitespace/punctuation to `-`
/// - removes Arabic diacritics
/// - keeps letters+digits across unicode (not only a-z)
String _normalizeStemKey(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return '';
  s = s.replaceAll(_arabicDiacritics, '');
  s = s.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-');
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

  final alias = _kPlaceImageStemAliases[n];

  // Fast path: membership check against manifest keys (no byte loading).
  final keys = await _loadImageKeySetFromManifest();
  String? tryExact(String stem) {
    for (final ext in const ['.jpeg', '.jpg', '.png']) {
      final path = 'images/$stem$ext';
      if (keys.contains(path)) return path;
    }
    return null;
  }

  final direct = tryExact(n);
  if (direct != null) return direct;
  if (alias != null) {
    final aliased = tryExact(alias);
    if (aliased != null) return aliased;
  }

  // Normalized match: handles spaces, punctuation, underscores, and unicode letters.
  final wanted = _normalizeStemKey(n);
  if (wanted.isEmpty) return null;
  final aliasKey = alias != null ? _normalizeStemKey(alias) : null;
  final normMap = await _loadNormalizedStemToPathFromManifest();
  final resolved =
      normMap[wanted] ?? (aliasKey != null ? normMap[aliasKey] : null);

  if (kDebugMode && resolved == null) {
    // Print a small, actionable diagnostic when matching fails.
    final attempted = <String>[
      'images/$n.jpeg',
      'images/$n.jpg',
      'images/$n.png',
      if (alias != null) 'images/$alias.jpeg',
      if (alias != null) 'images/$alias.jpg',
      if (alias != null) 'images/$alias.png',
    ];
    final candidates = <String>[];
    for (final path in keys) {
      final name = path.substring(path.lastIndexOf('/') + 1);
      final dot = name.lastIndexOf('.');
      final stem = dot > 0 ? name.substring(0, dot) : name;
      if (_normalizeStemKey(stem) == wanted) {
        candidates.add(path);
        if (candidates.length >= 6) break;
      }
    }
    debugPrint(
      '[PlaceImage] not found for "$n" (key=$wanted). '
      'attempted=${attempted.join(', ')} '
      'manifestCandidates=${candidates.isEmpty ? 'none' : candidates.join(', ')} '
      'manifestImageCount=${keys.length}',
    );
  }

  return resolved;
}

/// Warms up the internal manifest caches so first image resolution is instant.
Future<void> prewarmPlaceImageResolver() async {
  try {
    await _loadImageKeySetFromManifest();
    await _loadNormalizedStemToPathFromManifest();
  } catch (_) {}
}

Set<String>? _cachedManifestImageKeys;
Map<String, String>? _cachedNormalizedStemToPath;

Future<Set<String>> _loadImageKeySetFromManifest() async {
  final cached = _cachedManifestImageKeys;
  if (cached != null) return cached;
  // Flutter 3.38+ may ship only `AssetManifest.bin` at runtime.
  // Prefer the typed loader; keep JSON as a fallback for older toolchains.
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    final out = <String>{};
    for (final key in assets) {
      if (!key.startsWith('images/')) continue;
      if (key.endsWith('.jpeg') ||
          key.endsWith('.jpg') ||
          key.endsWith('.png')) {
        out.add(key);
      }
    }
    _cachedManifestImageKeys = out;
    return out;
  } catch (_) {
    try {
      final raw = await rootBundle.loadString('AssetManifest.json');
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final out = <String>{};
        for (final k in decoded.keys) {
          final key = k.toString();
          if (!key.startsWith('images/')) continue;
          if (key.endsWith('.jpeg') ||
              key.endsWith('.jpg') ||
              key.endsWith('.png')) {
            out.add(key);
          }
        }
        _cachedManifestImageKeys = out;
        return out;
      }
    } catch (_) {}
  }
  _cachedManifestImageKeys = const {};
  return const {};
}

Future<Map<String, String>> _loadNormalizedStemToPathFromManifest() async {
  final cached = _cachedNormalizedStemToPath;
  if (cached != null) return cached;
  final keys = await _loadImageKeySetFromManifest();
  final out = <String, String>{};
  for (final path in keys) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final key = _normalizeStemKey(stem);
    if (key.isEmpty) continue;
    // Prefer first match to keep stable mapping.
    out.putIfAbsent(key, () => path);
  }
  _cachedNormalizedStemToPath = out;
  return out;
}
