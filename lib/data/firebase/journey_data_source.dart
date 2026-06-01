import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/journey.dart';
import 'landmark_memory_data_source.dart';

/// Firestore access for journeys collection.
class JourneyDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'journeys';
  static const Duration _catalogCacheTtl = Duration(minutes: 15);

  static List<Journey>? _catalogCache;
  static DateTime? _catalogCachedAt;

  static void clearCatalogCache() {
    _catalogCache = null;
    _catalogCachedAt = null;
  }

  /// Document id variants (`journey_1` vs `journey1`, etc.).
  static List<String> docIdVariants(String journeyId) {
    final jid = journeyId.trim();
    if (jid.isEmpty) return const [];

    final out = <String>{jid};
    final normalized = LandmarkMemoryDataSource.normalizeCatalogJourneyId(
      catalogJourneyId: jid,
    );
    if (normalized.isNotEmpty) out.add(normalized);
    out.add(jid.replaceAll('_', ''));

    final match = RegExp(r'^journey_?(\d+)$', caseSensitive: false).firstMatch(jid);
    if (match != null) {
      final num = match.group(1)!;
      out.add('journey_$num');
      out.add('journey$num');
    }
    return out.toList();
  }

  static bool _idsMatch(String a, String b) {
    if (a == b) return true;
    if (a.replaceAll('_', '') == b.replaceAll('_', '')) return true;
    for (final va in docIdVariants(a)) {
      for (final vb in docIdVariants(b)) {
        if (va == vb) return true;
      }
    }
    return false;
  }

  /// Returns a journey from the in-memory catalog cache when [getAll] already ran.
  static Journey? findInCatalogCache(String journeyId) {
    final list = _catalogCache;
    if (list == null) return null;
    final target = journeyId.trim();
    if (target.isEmpty) return null;
    for (final j in list) {
      if (_idsMatch(j.journeyId, target)) return j;
    }
    return null;
  }

  static void _mergeIntoCatalogCache(Journey journey) {
    final list = List<Journey>.from(_catalogCache ?? const []);
    final i = list.indexWhere((j) => _idsMatch(j.journeyId, journey.journeyId));
    if (i >= 0) {
      list[i] = journey;
    } else {
      list.add(journey);
    }
    _catalogCache = list;
    _catalogCachedAt = DateTime.now();
  }

  /// Fetches a journey by document ID. Returns null if not found.
  Future<Journey?> getById(String journeyId) async {
    for (final tryId in docIdVariants(journeyId)) {
      final cached = findInCatalogCache(tryId);
      if (cached != null) return cached;
    }

    for (final tryId in docIdVariants(journeyId)) {
      final doc = await _firestore.collection(_collection).doc(tryId).get();
      if (!doc.exists || doc.data() == null) continue;
      final data = Map<String, dynamic>.from(doc.data()!);
      final journey = Journey.fromMap(data, id: doc.id);
      _mergeIntoCatalogCache(journey);
      return journey;
    }
    return null;
  }

  /// Fetches all journeys. Returns empty list if none.
  Future<List<Journey>> getAll() async {
    final cached = _catalogCache;
    final at = _catalogCachedAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _catalogCacheTtl) {
      return cached;
    }

    final snapshot = await _firestore.collection(_collection).get();
    final list = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      return Journey.fromMap(data, id: doc.id);
    }).toList();

    _catalogCache = list;
    _catalogCachedAt = DateTime.now();
    return list;
  }

  Future<void> create({
    required String journeyId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(_collection).doc(journeyId).set(
          data,
          SetOptions(merge: false),
        );
  }

  Future<void> update({
    required String journeyId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(_collection).doc(journeyId).set(
          data,
          SetOptions(merge: true),
        );
  }
}
