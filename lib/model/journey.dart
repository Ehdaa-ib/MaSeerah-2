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

  /// Firestore `journey_landmarks.journeyId` value (e.g. `journey1`). Optional catalog hint for admins.
  final String? landmarksJourneyId;

  /// When false, the journey is not playable yet (Coming Soon).
  final bool isAvailable;

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
    this.landmarksJourneyId,
    this.isAvailable = true,
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
      final normalized = e.key.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');
      if (!wantedNormalized.contains(normalized)) continue;
      final s = _coerceName(e.value);
      if (s != null) return s;
    }
    return 'Journey';
  }

  static String? _optionalString(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  static double _priceFromMap(Map<String, dynamic> map) {
    final v = map['price'] ?? map['amount'] ?? map['cost'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim()) ?? 0;
    return 0;
  }

  static String? _stopsFromMap(Map<String, dynamic> map) {
    final s = _optionalString(map, const [
      'stops',
      'stopCount',
      'numberOfStops',
      'stops_count',
    ]);
    if (s != null) return s;
    final v = map['stops'];
    if (v is num) return v.toString();
    return null;
  }

  static bool _isAvailableFromMap(Map<String, dynamic> map, {String? id}) {
    if (map['comingSoon'] == true) return false;
    if (map['isAvailable'] == false) return false;
    final status = (map['status'] as String?)?.trim().toLowerCase();
    if (status == 'coming_soon' ||
        status == 'comingsoon' ||
        status == 'unavailable' ||
        status == 'draft') {
      return false;
    }
    if (status == 'available' || status == 'released' || status == 'live') {
      return true;
    }
    final jid = (id ?? map['journeyId'] as String? ?? '').trim().toLowerCase();
    final normalized = jid.replaceAll('_', '');
    if (normalized == 'journey1') return true;
    if (normalized == 'journey2' || normalized == 'journey3') return false;
    return true;
  }

  factory Journey.fromMap(Map<String, dynamic> map, {String? id}) {
    final journeyId = id ?? map['journeyId'] as String? ?? '';
    return Journey(
      journeyId: journeyId,
      name: _nameFromFirestore(map),
      price: _priceFromMap(map),
      description: _optionalString(map, const [
        'description',
        'about',
        'overview',
        'summary',
        'journeyDescription',
      ]),
      startPoint: _optionalString(map, const [
        'startPoint',
        'start_point',
        'startingPoint',
      ]),
      endPoint: _optionalString(map, const [
        'endPoint',
        'end_point',
        'endingPoint',
      ]),
      stops: _stopsFromMap(map),
      estimatedDuration: _optionalString(map, const [
        'estimatedDuration',
        'duration',
        'estimated_duration',
        'tripDuration',
      ]),
      distance: _optionalString(map, const [
        'distance',
        'totalDistance',
        'distance_km',
      ]),
      goodToKnow: _optionalString(map, const [
        'goodToKnow',
        'good_to_know',
        'tips',
        'knowBeforeYouGo',
      ]),
      languages: _optionalString(map, const ['languages', 'language']),
      city: _optionalString(map, const ['city', 'location', 'region']),
      landmarksJourneyId: _optionalString(map, const [
        'landmarksJourneyId',
        'landmarks_journey_id',
        'landmarkJourneyId',
      ]),
      isAvailable: _isAvailableFromMap(map, id: journeyId),
    );
  }
}
