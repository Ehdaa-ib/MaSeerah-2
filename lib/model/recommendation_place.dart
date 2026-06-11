import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// FR-21/22: optional place recommendations for the journey map (Firestore-backed).
class RecommendationPlace {
  RecommendationPlace({
    required this.id,
    required this.name,
    required this.description,
    required this.locationUrl,
    required this.order,
    required this.averagePrice,
    required this.distanceLabel,
    required this.walkingLabel,
    this.rating,
    this.imageUrls = const [],
    this.pricesRaw,
    this.landmarksJourneyId,
    this.catalogJourneyId,
  });

  final String id;
  final String name;
  final String description;

  /// Google Maps link opened by the recommendation UI.
  /// Populated from Firestore `location` (string or GeoPoint), then `locationUrl`, `mapsUrl`, `url`.
  final String locationUrl;

  /// Display sequence (1…n), not landmark region index.
  final int order;

  final String averagePrice;
  final String distanceLabel;
  final String walkingLabel;
  final double? rating;

  /// Download URLs from Firestore `images` (http/https only).
  final List<String> imageUrls;

  /// First image URL; same as [imageUrls.first] when non-empty.
  String? get primaryImageUrl => imageUrls.isEmpty ? null : imageUrls.first;

  /// Raw map/list from Firestore for the detailed popup.
  final Object? pricesRaw;

  /// Optional filters when multiple journeys share one collection.
  final String? landmarksJourneyId;
  final String? catalogJourneyId;

  /// [fallbackOrder] is used when no order-like field exists (Firestore `orderBy` would hide these docs).
  static RecommendationPlace? fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int? fallbackOrder,
  }) {
    final d = doc.data();
    if (d == null) return null;

    final orderRaw =
        d['order'] ??
        d['orderIndex'] ??
        d['sortOrder'] ??
        d['displayOrder'] ??
        d['sequence'] ??
        d['index'] ??
        d['rank'] ??
        d['position'];
    var order = orderRaw is int
        ? orderRaw
        : orderRaw is num
        ? orderRaw.toInt()
        : int.tryParse(orderRaw?.toString().trim() ?? '');
    order ??= fallbackOrder;
    if (order == null) return null;

    final name = _readString(d, const ['name', 'title']) ?? 'Place';
    final description =
        _readString(d, const ['description', 'desc', 'details']) ?? '';
    final locationUrl = _readMapsLink(d);

    final distanceLabel = _formatDistanceOrWalk(
      d['distnaceFromPreviosLandmark'] ??
          d['distanceFromPreviousLandmark'] ??
          d['distance_from_previous_landmark'] ??
          d['distance'] ??
          d['distanceFromPrevious'],
    );
    final walkingLabel = _formatDistanceOrWalk(
      d['avgWalkingTime'] ??
          d['averageWalkingTime'] ??
          d['walkingTime'] ??
          d['walking'],
    );

    final averagePrice =
        _readString(d, const ['averagePrice', 'avgPrice', 'average_price']) ??
        '—';

    final rating = _readRating(d['rating'] ?? d['googleRating'] ?? d['stars']);

    final images = _imagesFromFirestore(d, debugDocId: doc.id);

    if (kDebugMode) {
      debugPrint(
        '[RecommendationPlace] id=${doc.id} name="$name" order=$order '
        'imageUrls.count=${images.length}',
      );
    }
    return RecommendationPlace(
      id: doc.id,
      name: name.trim(),
      description: description.trim(),
      locationUrl: locationUrl.trim(),
      order: order,
      averagePrice: averagePrice.trim().isEmpty ? '—' : averagePrice.trim(),
      distanceLabel: distanceLabel,
      walkingLabel: walkingLabel,
      rating: rating,
      imageUrls: images,
      pricesRaw: d['prices'],
      landmarksJourneyId: _readString(d, const [
        'landmarksJourneyId',
        'landmarks_journey_id',
        'journeyLandmarksId',
      ]),
      catalogJourneyId: _readString(d, const [
        'catalogJourneyId',
        'catalog_journey_id',
        'journeyId',
      ]),
    );
  }

  /// Resolves the maps/directions target from Firestore. Tries [location] first.
  static String _readMapsLink(Map<String, dynamic> d) {
    for (final k in const [
      'location',
      'locationUrl',
      'location_url',
      'mapsUrl',
      'url',
    ]) {
      final v = d[k];
      if (v == null) continue;
      if (v is GeoPoint) {
        return 'https://www.google.com/maps/search/?api=1&query=${v.latitude},${v.longitude}';
      }
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) return s;
        continue;
      }
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '';
  }

  static String? _readString(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static double? _readRating(Object? v) {
    if (v == null) return null;
    if (v is double) return v.isFinite ? v : null;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
    return null;
  }

  static String _formatDistanceOrWalk(Object? v) {
    if (v == null) return '—';
    if (v is num) {
      // Heuristic: large values → meters as text; small → minutes if < 240 else meters
      final n = v.toDouble();
      if (n >= 500 && n == n.roundToDouble()) return '${n.round()} m';
      if (n <= 240 && n == n.roundToDouble()) return '${n.round()} min';
      if (n < 60) {
        return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)} min';
      }
      return '${n.round()} m';
    }
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  /// Reads Firestore list fields for gallery URLs. Tries [images], then [image], [photoUrls], [photos].
  /// Keeps order; skips invalid entries. Only `http`/`https` strings are kept (`gs://` is skipped — use download URLs).
  static List<String> _imagesFromFirestore(
    Map<String, dynamic> d, {
    String? debugDocId,
  }) {
    void log(String msg) {
      if (kDebugMode) {
        debugPrint(
          '[RecommendationImages${debugDocId != null ? ' doc=$debugDocId' : ''}] $msg',
        );
      }
    }

    final raw = _coerceImageListRaw(d);
    if (raw == null) {
      log(
        'no usable field: tried images, photoUrls, photos, or single image/photo/imageUrl — all null/empty',
      );
      return [];
    }
    final out = <String>[];
    final seen = <String>{};
    for (var i = 0; i < raw.length; i++) {
      final e = raw[i];
      if (e == null) {
        log('index $i: null entry skipped');
        continue;
      }
      if (e is! String) {
        log('index $i: skipped (expected String, got ${e.runtimeType})');
        continue;
      }
      final t = e.trim();
      if (t.isEmpty) {
        log('index $i: skipped (empty string)');
        continue;
      }
      if (t.startsWith('gs://')) {
        log(
          'index $i: skipped (gs:// — store a full https download URL from Firebase Storage): ${_preview(t, 100)}',
        );
        continue;
      }
      if (!t.startsWith('http')) {
        log(
          'index $i: skipped (must start with http/https): ${_preview(t, 120)}',
        );
        continue;
      }
      if (!seen.add(t)) {
        log('index $i: skipped (duplicate URL)');
        continue;
      }
      out.add(t);
    }

    if (kDebugMode) {
      if (out.isEmpty && raw.isNotEmpty) {
        log(
          'parsed 0 usable URLs from ${raw.length} list entries (see skip reasons above)',
        );
      } else if (out.isNotEmpty) {
        for (var i = 0; i < out.length; i++) {
          log('kept[$i]=${_preview(out[i], 140)}');
        }
      }
    }

    return out;
  }

  /// Returns a non-empty list of raw entries from Firestore, or null.
  static List<dynamic>? _coerceImageListRaw(Map<String, dynamic> d) {
    for (final key in ['images', 'photoUrls', 'photos']) {
      final v = d[key];
      if (v is List && v.isNotEmpty) return v;
    }
    final single = d['image'] ?? d['photo'] ?? d['photoUrl'] ?? d['imageUrl'];
    if (single is String && single.trim().isNotEmpty) {
      return [single.trim()];
    }
    return null;
  }

  static String _preview(String s, int max) {
    final t = s.replaceAll('\n', ' ');
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}
