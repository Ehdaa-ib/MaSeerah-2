/// Journey entity for display and pricing when creating orders.
class Journey {
  final String journeyId;
  final String name;
  final double price;
  final String? description;
  final String? startPoint;
  final String? endPoint;
  final String? stops;
  final String? estimatedDuration;
  final String? distance;
  final String? goodToKnow;
  final String? languages;
  final String? city;

  Journey({
    required this.journeyId,
    required this.name,
    required this.price,
    this.description,
    this.startPoint,
    this.endPoint,
    this.stops,
    this.estimatedDuration,
    this.distance,
    this.goodToKnow,
    this.languages,
    this.city,
  });

  static String? _coerceName(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  /// Resolves a human-readable title from whatever fields exist on `journeys/{id}`.
  static String _nameFromFirestore(Map<String, dynamic> map) {
    const preferredKeys = [
      'journey_name',
      'name',
      'title',
      'journeyName',
      'displayName',
      'journeyTitle',
      'tripName',
      'label',
      'journey_title',
      'name_en',
      'nameEn',
      'journeyLabel',
    ];
    for (final key in preferredKeys) {
      final s = _coerceName(map[key]);
      if (s != null) return s;
    }
    const wantedNormalized = <String>{
      'journeyname',
      'name',
      'title',
      'displayname',
      'journeytitle',
      'tripname',
      'label',
      'nameen',
      'journeylabel',
    };
    for (final e in map.entries) {
      final normalized =
          e.key.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');
      if (!wantedNormalized.contains(normalized)) continue;
      final s = _coerceName(e.value);
      if (s != null) return s;
    }
    return 'Journey';
  }

  factory Journey.fromMap(Map<String, dynamic> map, {String? id}) {
    return Journey(
      journeyId: id ?? map['journeyId'] as String? ?? '',
      name: _nameFromFirestore(map),
      price: (map['price'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      startPoint: map['startPoint'] as String?,
      endPoint: map['endPoint'] as String?,
      stops: map['stops'] as String?,
      estimatedDuration: map['estimatedDuration'] as String?,
      distance: map['distance'] as String?,
      goodToKnow: map['goodToKnow'] as String?,
      languages: map['languages'] as String?,
      city: map['city'] as String?,
    );
  }
}
