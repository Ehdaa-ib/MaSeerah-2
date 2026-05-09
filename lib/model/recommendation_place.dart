import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.primaryImageUrl,
    this.imageUrls = const [],
    this.pricesRaw,
    this.landmarksJourneyId,
    this.catalogJourneyId,
  });

  final String id;
  final String name;
  final String description;

  /// Google Maps / place URL opened by [Directions].
  final String locationUrl;

  /// Display sequence (1…n), not landmark region index.
  final int order;

  final String averagePrice;
  final String distanceLabel;
  final String walkingLabel;
  final double? rating;

  final String? primaryImageUrl;
  final List<String> imageUrls;

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

    final orderRaw = d['order'] ??
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
    final description = _readString(d, const ['description', 'desc', 'details']) ?? '';
    final locationUrl = _readString(d, const ['locationUrl', 'location_url', 'mapsUrl', 'url']) ?? '';

    final distanceLabel = _formatDistanceOrWalk(
      d['distnaceFromPreviosLandmark'] ??
          d['distanceFromPreviousLandmark'] ??
          d['distance_from_previous_landmark'] ??
          d['distance'] ??
          d['distanceFromPrevious'],
    );
    final walkingLabel = _formatDistanceOrWalk(
      d['avgWalkingTime'] ?? d['averageWalkingTime'] ?? d['walkingTime'] ?? d['walking'],
    );

    final averagePrice = _readString(d, const ['averagePrice', 'avgPrice', 'average_price']) ?? '—';

    final rating = _readRating(d['rating'] ?? d['googleRating'] ?? d['stars']);

    final images = _collectImageUrls(d);

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
      primaryImageUrl: images.isNotEmpty ? images.first : null,
      imageUrls: images,
      pricesRaw: d['prices'],
      landmarksJourneyId: _readString(d, const ['landmarksJourneyId', 'landmarks_journey_id', 'journeyLandmarksId']),
      catalogJourneyId: _readString(d, const ['catalogJourneyId', 'catalog_journey_id', 'journeyId']),
    );
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
      if (n < 60) return '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)} min';
      return '${n.round()} m';
    }
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  static List<String> _collectImageUrls(Map<String, dynamic> d) {
    final out = <String>[];
    void addUrl(Object? o) {
      if (o is String) {
        final t = o.trim();
        if (t.startsWith('http')) out.add(t);
      }
    }

    addUrl(d['imageUrl'] ?? d['imageURL'] ?? d['photoUrl']);
    final imgs = d['images'] ?? d['imageUrls'] ?? d['photos'];
    if (imgs is List) {
      for (final e in imgs) {
        addUrl(e);
      }
    }
    return out.toSet().toList();
  }
}
