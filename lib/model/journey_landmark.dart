import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../challenge/challenge_quiz_parser.dart';
import 'challenge_model.dart';

/// Document in `journey_landmarks/{docId}`.
/// **Region** on the map is tied to **[order]** (order 1 → region 1), not the document id.
class JourneyLandmark {
  JourneyLandmark({
    required this.documentId,
    required this.journeyId,
    required this.order,
    required this.name,
    this.description,
    this.distanceFromPreviousMeters,
    this.walkingTimeFromPreviousMinutes,
    this.latitude,
    this.longitude,
    this.challenge,
    this.nextLandmarkId,
  });

  /// Canonical Firestore field names (also try [firestoreDistanceAliases] / [firestoreWalkingTimeAliases]).
  static const String firestoreFieldDistanceFromPreviousMeters = 'distanceFromPreviousMeters';
  static const String firestoreFieldWalkingTimeFromPreviousMinutes = 'walkingTimeFromPreviousMinutes';

  static const List<String> firestoreDistanceAliases = [
    firestoreFieldDistanceFromPreviousMeters,
    'distance_from_previous_meters',
    'distanceFromPrevious',
    'distance_from_previous',
    'distanceMeters',
    'distance_meters',
  ];

  static const List<String> firestoreWalkingTimeAliases = [
    firestoreFieldWalkingTimeFromPreviousMinutes,
    'walking_time_from_previous_minutes',
    'walkingTimeFromPrevious',
    'walking_time_from_previous',
    'walkingMinutesFromPrevious',
    'walking_minutes_from_previous',
    'avgWalkingTimeMinutes',
    'avg_walking_time_minutes',
  ];

  final String documentId;
  final String journeyId;

  /// Visit order; matches SVG **region** index (1 → region 1).
  final int order;
  final String name;

  /// Longer copy for the region sheet; from Firestore `description` (and common aliases).
  final String? description;

  /// Leg from the previous landmark in the journey (meaningful for [order] > 1).
  /// Stored in Firestore as numeric (often [double]); parsed without rounding away decimals.
  final double? distanceFromPreviousMeters;
  final double? walkingTimeFromPreviousMinutes;

  /// Destination coordinates for external Google Maps.
  final double? latitude;
  final double? longitude;

  /// Parsed `quiz` field when present (direct or `stageN`); null if absent / unparsable.
  final ChallengeModel? challenge;

  /// Optional Firestore landmark document id for the next stop (challenge navigation).
  final String? nextLandmarkId;

  bool get hasCoordinates =>
      latitude != null && longitude != null && latitude!.isFinite && longitude!.isFinite;

  static String? _readDescription(Map<String, dynamic> data) {
    const keys = ['description', 'landmarkDescription', 'about', 'desc', 'details'];
    for (final key in keys) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  factory JourneyLandmark.fromFirestore(String docId, Map<String, dynamic> data) {
    final order = _readOrder(data);
    final lat = _readLatitude(data);
    final lng = _readLongitude(data);
    return JourneyLandmark(
      documentId: docId,
      journeyId: (data['journeyId'] as String?) ?? '',
      order: order,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'Landmark',
      description: _readDescription(data),
      distanceFromPreviousMeters: _readDistanceFromLandmarkData(data),
      walkingTimeFromPreviousMinutes: _readWalkingTimeFromLandmarkData(data, docId),
      latitude: lat,
      longitude: lng,
      challenge: ChallengeQuizParser.tryParse(
        data['quiz'],
        landmarkDocumentId: docId,
      ),
      nextLandmarkId: _readNextLandmarkId(data),
    );
  }

  static String? _readNextLandmarkId(Map<String, dynamic> data) {
    for (final key in ['nextLandmarkId', 'nextLandmark', 'nextLandmarkDocId']) {
      final v = data[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? o) {
    if (o == null) return null;
    if (o is Map<String, dynamic>) return o;
    if (o is Map) return o.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  /// First non-null finite numeric among [keys] on [data] (top-level).
  static double? _readFirstDoubleFromKeys(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (!data.containsKey(key)) continue;
      final v = _coerceToDouble(data[key]);
      if (v != null && v.isFinite) return v;
    }
    return null;
  }

  /// Same as [_readFirstDoubleFromKeys], then common nested maps used by CMS (`route`, `leg`, …).
  static double? _readNumericFromLandmarkData(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    final top = _readFirstDoubleFromKeys(data, keys);
    if (top != null) return top;
    for (final nest in ['route', 'leg', 'segment', 'navigation', 'meta', 'details']) {
      final inner = _asStringKeyedMap(data[nest]);
      if (inner == null) continue;
      final v = _readFirstDoubleFromKeys(inner, keys);
      if (v != null) return v;
    }
    return null;
  }

  static double? _readDistanceFromLandmarkData(Map<String, dynamic> data) {
    return _readNumericFromLandmarkData(data, firestoreDistanceAliases);
  }

  static String _normalizeFieldKey(String k) =>
      k.replaceAll(RegExp(r'[\s_-]'), '').toLowerCase();

  static const String _walkingCanonicalNorm = 'walkingtimefrompreviousminutes';

  /// Reads `walkingTimeFromPreviousMinutes` with **case-insensitive** key match (Firestore / CMS typos).
  /// Also checks nested `route` / `leg` / … maps for the same field.
  static double? walkingTimeFromPreviousMinutesFromRawMap(
    Map<String, dynamic> data, {
    String? debugDocId,
  }) {
    for (final e in data.entries) {
      if (_normalizeFieldKey(e.key) == _walkingCanonicalNorm) {
        return parseWalkingTimeFromPreviousMinutesValue(e.value, debugDocId: debugDocId);
      }
    }
    for (final nest in ['route', 'leg', 'segment', 'navigation', 'meta', 'details']) {
      final inner = _asStringKeyedMap(data[nest]);
      if (inner == null) continue;
      for (final e in inner.entries) {
        if (_normalizeFieldKey(e.key) == _walkingCanonicalNorm) {
          return parseWalkingTimeFromPreviousMinutesValue(
            e.value,
            debugDocId: '${debugDocId ?? '?'}/$nest',
          );
        }
      }
    }
    return null;
  }

  /// Parses Firestore field [walkingTimeFromPreviousMinutes] only (exact name).
  /// Handles [int], [double], [num], and numeric [String].
  static double? parseWalkingTimeFromPreviousMinutesValue(
    Object? raw, {
    String? debugDocId,
  }) {
    if (raw == null) return null;
    double? out;
    if (raw is int) {
      out = raw.toDouble();
    } else if (raw is double) {
      out = raw.isFinite ? raw : null;
    } else if (raw is num) {
      final d = raw.toDouble();
      out = d.isFinite ? d : null;
    } else if (raw is String) {
      var t = raw.trim();
      if (t.isEmpty) return null;
      if (t.contains(',') && !t.contains('.')) {
        t = t.replaceFirst(',', '.');
      }
      out = double.tryParse(t);
    } else {
      out = double.tryParse(raw.toString());
    }
    if (kDebugMode) {
      debugPrint(
        '[JourneyLandmark] walkingTimeFromPreviousMinutes doc=${debugDocId ?? '?'} '
        'raw=$raw runtimeType=${raw.runtimeType} parsed=$out',
      );
    }
    return out;
  }

  static double? _readWalkingTimeFromLandmarkData(Map<String, dynamic> data, String docId) {
    final flex = walkingTimeFromPreviousMinutesFromRawMap(data, debugDocId: docId);
    if (flex != null) return flex;

    return _readNumericFromLandmarkData(data, firestoreWalkingTimeAliases);
  }

  /// Reads a nullable int from [data] for [key]. Null-safe; supports Firestore [int], [double]/[num]
  /// (common on web/JS interop for integer fields), numeric [String], and other numeric-like values.
  static int? _readFirestoreInt(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return null;
    return _coerceToInt(data[key]);
  }

  static int? _coerceToInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return null;
      // Whole numbers only; avoids silent truncation of true fractional values.
      final r = value.round();
      if ((value - r).abs() > 1e-6) return null;
      return r;
    }
    if (value is num) {
      final d = value.toDouble();
      if (d.isNaN || d.isInfinite) return null;
      final r = d.round();
      if ((d - r).abs() > 1e-6) return null;
      return r;
    }
    if (value is String) {
      final t = value.trim();
      if (t.isEmpty) return null;
      return int.tryParse(t);
    }
    // Rare: platform-specific numeric wrappers; `toString()` then [num.parse] is last resort.
    try {
      final n = num.tryParse(value.toString());
      if (n == null) return null;
      final d = n.toDouble();
      if (d.isNaN || d.isInfinite) return null;
      return d.round();
    } catch (_) {
      return null;
    }
  }

  /// Prefer field `order`; fall back to `landmarkNumber` for older documents.
  static int _readOrder(Map<String, dynamic> data) {
    final o = _readFirestoreInt(data, 'order');
    if (o != null && o > 0) return o;
    final legacy = _readFirestoreInt(data, 'landmarkNumber');
    if (legacy != null && legacy > 0) return legacy;
    return 0;
  }

  static double? _readLatitude(Map<String, dynamic> data) {
    final direct = data['latitude'] ?? data['lat'];
    final n = _coerceToDouble(direct);
    if (n != null) return n;
    for (final key in ['location', 'coordinates', 'position']) {
      final g = data[key];
      if (g is GeoPoint) return g.latitude;
    }
    return null;
  }

  static double? _readLongitude(Map<String, dynamic> data) {
    final direct = data['longitude'] ?? data['lng'];
    final n = _coerceToDouble(direct);
    if (n != null) return n;
    for (final key in ['location', 'coordinates', 'position']) {
      final g = data[key];
      if (g is GeoPoint) return g.longitude;
    }
    return null;
  }

  static double? _coerceToDouble(Object? value) {
    if (value == null) return null;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      var t = value.trim();
      if (t.isEmpty) return null;
      // Locale-friendly: "12,5" minutes / meters
      if (t.contains(',') && !t.contains('.')) {
        t = t.replaceFirst(',', '.');
      }
      return double.tryParse(t);
    }
    try {
      return double.tryParse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
