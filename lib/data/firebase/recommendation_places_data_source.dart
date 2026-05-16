import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../model/recommendation_place.dart';

/// Reads curated recommendation places for the map (FR-21/22).
/// Collection documents can optionally include [landmarksJourneyId] / [catalogJourneyId] to scope by journey.
class RecommendationPlacesDataSource {
  RecommendationPlacesDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Change this if your Firebase collection uses a different id.
  static const String collectionName = 'recommendation_places';

  static const List<String> _collectionCandidates = [
    'recommendations',
    collectionName,
    'recommended_places',
  ];

  Future<List<RecommendationPlace>> fetchForJourney({
    required String landmarksJourneyId,
    String? catalogJourneyId,
  }) async {
    for (final name in _collectionCandidates) {
      try {
        final all = await _fetchAllFromCollection(name);
        if (all.isEmpty) continue;

        final scoped = _applyJourneyScope(
          all,
          landmarksJourneyId: landmarksJourneyId,
          catalogJourneyId: catalogJourneyId,
        );
        if (kDebugMode) {
          debugPrint(
            '[RecommendationPlaces] collection=$name docs=${all.length} '
            'afterScope=${scoped.length} landmarks="$landmarksJourneyId" catalog="${catalogJourneyId ?? ''}"',
          );
        }
        return scoped;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[RecommendationPlaces] collection=$name failed: $e\n$st');
        }
      }
    }
    return [];
  }

  Future<List<RecommendationPlace>> _fetchAllFromCollection(String id) async {
    final col = _db.collection(id);

    // Prefer a full collection read: Firestore [orderBy('order')] **omits documents that lack that field**,
    // which looks like an empty collection even when docs exist (wrong/missing field name).
    QuerySnapshot<Map<String, dynamic>> snap = await col.get();

    if (snap.docs.isEmpty && kDebugMode) {
      debugPrint('[RecommendationPlaces] collection=$id rawDocs=0 (empty or no read access)');
    }

    final all = <RecommendationPlace>[];
    for (var i = 0; i < snap.docs.length; i++) {
      final p = RecommendationPlace.fromDoc(snap.docs[i], fallbackOrder: i + 1);
      if (p != null) all.add(p);
    }

    if (kDebugMode && snap.docs.isNotEmpty && all.isEmpty) {
      final sample = snap.docs.first.data();
      debugPrint(
        '[RecommendationPlaces] collection=$id rawDocs=${snap.docs.length} parsed=0 — '
        'each doc needs a numeric `order` (or orderIndex/sortOrder/…); sample keys=${sample.keys.toList()}',
      );
    }

    all.sort((a, b) => a.order.compareTo(b.order));
    return all;
  }

  List<RecommendationPlace> _applyJourneyScope(
    List<RecommendationPlace> all, {
    required String landmarksJourneyId,
    String? catalogJourneyId,
  }) {
    if (all.isEmpty) return [];

    bool matches(RecommendationPlace p) {
      final lj = p.landmarksJourneyId?.trim();
      final cj = p.catalogJourneyId?.trim();
      if (lj == null && cj == null) return true;
      if (landmarksJourneyId.isNotEmpty && lj == landmarksJourneyId.trim()) return true;
      final cat = catalogJourneyId?.trim();
      if (cat != null && cat.isNotEmpty && cj == cat) return true;
      return false;
    }

    final filtered = all.where(matches).toList();
    if (filtered.isEmpty) return all;

    // Mis-tagged rows: journey filter dropped some of the first five places (by `order`) — use full list.
    final sortedAll = [...all]..sort((a, b) => a.order.compareTo(b.order));
    final topFiveIds = sortedAll.take(5).map((p) => p.id).toSet();
    final filteredIds = filtered.map((p) => p.id).toSet();
    if (topFiveIds.isNotEmpty && !topFiveIds.every(filteredIds.contains)) {
      return all;
    }

    return filtered;
  }
}
