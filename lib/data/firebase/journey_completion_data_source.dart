import 'package:cloud_firestore/cloud_firestore.dart';

import 'landmark_memory_data_source.dart';
import '../../util/ttl_cache.dart';

class JourneyCompletionDataSource {
  static const String _collection = 'journeyCompletions';

  /// Append-only history under the user profile (never removed by [clearCompletion]).
  static const String userCompletionHistorySubcollection =
      'journeyCompletionHistory';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _docId({required String userId, required String journeyId}) =>
      '${userId}_$journeyId';

  Future<void> markCompleted({
    required String userId,
    required String journeyId,
    String? userJourneyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    final mainRef = _firestore.collection(_collection).doc(docId);
    var instanceId = userJourneyId?.trim() ?? '';
    if (instanceId.isEmpty ||
        LandmarkMemoryDataSource.isCatalogJourneyDocId(
          instanceId,
          catalogJourneyId: journeyId,
        )) {
      instanceId = _firestore
          .collection('users')
          .doc(userId)
          .collection(userCompletionHistorySubcollection)
          .doc()
          .id;
    }
    final historyRef = _firestore
        .collection('users')
        .doc(userId)
        .collection(userCompletionHistorySubcollection)
        .doc(instanceId);

    final batch = _firestore.batch();
    batch.set(mainRef, {
      'userId': userId,
      'journeyId': journeyId,
      'userJourneyId': instanceId,
      'completedAt': FieldValue.serverTimestamp(),
      // Journey was finished on the map; feedback may still be pending.
      'awaitingFeedback': true,
    }, SetOptions(merge: true));
    batch.set(historyRef, {
      'userId': userId,
      'journeyId': journeyId,
      'userJourneyId': historyRef.id,
      'completedAt': FieldValue.serverTimestamp(),
      'awaitingFeedback': true,
    });
    await batch.commit();
  }

  Future<bool> isCompleted({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    final doc = await _firestore.collection(_collection).doc(docId).get();
    return doc.exists;
  }

  Future<bool> isAwaitingFeedback({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    final doc = await _firestore.collection(_collection).doc(docId).get();
    if (!doc.exists || doc.data() == null) return false;
    return doc.data()!['awaitingFeedback'] == true;
  }

  /// Clears completion so a new paid playthrough can start (call after a successful purchase).
  Future<void> clearCompletion({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    await _firestore.collection(_collection).doc(docId).delete();
  }

  /// Completion timestamps for this catalog journey (all playthroughs), oldest first.
  Future<List<DateTime>> listCompletionTimesForJourney({
    required String userId,
    required String journeyId,
  }) async {
    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) return const [];

    final variants = LandmarkMemoryDataSource.journeyIdVariants(jid);
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection(userCompletionHistorySubcollection)
        .get();

    final times = <DateTime>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final stored = (data['journeyId'] as String?)?.trim() ?? '';
      if (stored.isEmpty) continue;
      final storedVariants = LandmarkMemoryDataSource.journeyIdVariants(stored);
      if (!storedVariants.any(variants.contains)) continue;
      final ts = data['completedAt'];
      if (ts is Timestamp) times.add(ts.toDate());
    }
    times.sort();
    return times;
  }

  static String? _playthroughIdFromCompletionData({
    required String docId,
    required Map<String, dynamic> data,
  }) {
    final catalog = (data['journeyId'] as String?)?.trim();
    final fromField = (data['userJourneyId'] as String?)?.trim();
    if (fromField != null &&
        fromField.isNotEmpty &&
        !LandmarkMemoryDataSource.isCatalogJourneyDocId(
          fromField,
          catalogJourneyId: catalog,
        )) {
      return fromField;
    }
    if (!LandmarkMemoryDataSource.isCatalogJourneyDocId(
      docId,
      catalogJourneyId: catalog,
    )) {
      return docId;
    }
    return null;
  }

  static const Duration _resolveInstanceCacheTtl = Duration(minutes: 5);

  static String _resolveCacheKey({
    required String uid,
    String? completionDocId,
    String? historyDocId,
    DateTime? completedAt,
  }) {
    final at = completedAt?.millisecondsSinceEpoch ?? 0;
    return 'resolve_${uid}_${completionDocId ?? ''}_${historyDocId ?? ''}_$at';
  }

  /// Resolves the playthrough instance id for a profile history card.
  Future<String?> resolvePlaythroughInstanceId({
    required String userId,
    required String catalogJourneyId,
    String? completionDocId,
    String? historyDocId,
    DateTime? completedAt,
  }) async {
    final uid = userId.trim();
    final catalog = catalogJourneyId.trim();
    if (uid.isEmpty) return null;

    final cacheKey = _resolveCacheKey(
      uid: uid,
      completionDocId: completionDocId,
      historyDocId: historyDocId,
      completedAt: completedAt,
    );
    final cached = TtlCache.read<String>(cacheKey, _resolveInstanceCacheTtl);
    if (cached != null && cached.isNotEmpty) return cached;

    for (final raw in [completionDocId, historyDocId]) {
      final key = raw?.trim();
      if (key == null || key.isEmpty) continue;
      final fromDoc = await userJourneyIdForHistoryDoc(
        userId: uid,
        historyDocId: key,
      );
      if (fromDoc != null && fromDoc.isNotEmpty) {
        TtlCache.write(cacheKey, fromDoc);
        return fromDoc;
      }
    }

    if (catalog.isNotEmpty) {
      final variants = LandmarkMemoryDataSource.journeyIdVariants(catalog);
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(userCompletionHistorySubcollection)
          .get();

      String? bestId;
      Duration? bestDiff;
      for (final doc in snap.docs) {
        final data = doc.data();
        final stored = (data['journeyId'] as String?)?.trim() ?? '';
        if (stored.isEmpty) continue;
        final storedVariants = LandmarkMemoryDataSource.journeyIdVariants(
          stored,
        );
        if (!storedVariants.any(variants.contains)) continue;

        final playthroughId = _playthroughIdFromCompletionData(
          docId: doc.id,
          data: data,
        );
        if (playthroughId == null) continue;

        if (completedAt != null) {
          final ts = data['completedAt'];
          if (ts is! Timestamp) continue;
          final diff = ts.toDate().difference(completedAt).abs();
          if (diff.inMinutes > 5) continue;
          if (bestDiff == null || diff < bestDiff) {
            bestDiff = diff;
            bestId = playthroughId;
          }
        } else {
          TtlCache.write(cacheKey, playthroughId);
          return playthroughId;
        }
      }
      if (bestId != null) {
        TtlCache.write(cacheKey, bestId);
        return bestId;
      }

      final fromHistoryParents = await _resolveFromJourneyHistoryParents(
        userId: uid,
        catalogJourneyId: catalog,
        completedAt: completedAt,
      );
      if (fromHistoryParents != null && fromHistoryParents.isNotEmpty) {
        TtlCache.write(cacheKey, fromHistoryParents);
        return fromHistoryParents;
      }
    }

    return null;
  }

  Future<String?> _resolveFromJourneyHistoryParents({
    required String userId,
    required String catalogJourneyId,
    DateTime? completedAt,
  }) async {
    final variants = LandmarkMemoryDataSource.journeyIdVariants(
      catalogJourneyId,
    );
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection(LandmarkMemoryDataSource.journeyHistorySubcollection)
        .get();

    String? bestId;
    Duration? bestDiff;
    for (final doc in snap.docs) {
      if (LandmarkMemoryDataSource.isCatalogJourneyDocId(
        doc.id,
        catalogJourneyId: catalogJourneyId,
      )) {
        continue;
      }
      final data = doc.data();
      final stored = (data['journeyId'] as String?)?.trim() ?? '';
      if (stored.isNotEmpty) {
        final storedVariants = LandmarkMemoryDataSource.journeyIdVariants(
          stored,
        );
        if (!storedVariants.any(variants.contains)) continue;
      }

      final candidate =
          (data['userJourneyId'] as String?)?.trim() ??
          (data['journeyHistoryId'] as String?)?.trim() ??
          doc.id;
      if (LandmarkMemoryDataSource.isCatalogJourneyDocId(
        candidate,
        catalogJourneyId: catalogJourneyId,
      )) {
        continue;
      }

      if (completedAt != null) {
        final ts = data['completedAt'] ?? data['lastUpdatedAt'];
        if (ts is! Timestamp) continue;
        final diff = ts.toDate().difference(completedAt).abs();
        if (diff.inMinutes > 10) continue;
        if (bestDiff == null || diff < bestDiff) {
          bestDiff = diff;
          bestId = candidate;
        }
      } else {
        return candidate;
      }
    }
    return bestId;
  }

  /// Playthrough instance id for one `journeyCompletionHistory` document.
  Future<String?> userJourneyIdForHistoryDoc({
    required String userId,
    required String historyDocId,
  }) async {
    final uid = userId.trim();
    final hid = historyDocId.trim();
    if (uid.isEmpty || hid.isEmpty) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection(userCompletionHistorySubcollection)
        .doc(hid)
        .get();
    if (!doc.exists || doc.data() == null) return null;

    return _playthroughIdFromCompletionData(docId: doc.id, data: doc.data()!);
  }

  /// Latest completion row for this catalog journey (for linking feedback to a playthrough).
  Future<String?> latestUserJourneyId({
    required String userId,
    required String journeyId,
  }) async {
    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) return null;

    final variants = LandmarkMemoryDataSource.journeyIdVariants(jid);
    final snap = await _firestore
        .collection('users')
        .doc(uid)
        .collection(userCompletionHistorySubcollection)
        .orderBy('completedAt', descending: true)
        .limit(30)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final stored = (data['journeyId'] as String?)?.trim() ?? '';
      if (stored.isEmpty) continue;
      final storedVariants = LandmarkMemoryDataSource.journeyIdVariants(stored);
      if (!storedVariants.any(variants.contains)) continue;
      final fromField = (data['userJourneyId'] as String?)?.trim();
      if (fromField != null && fromField.isNotEmpty) return fromField;
      return doc.id;
    }
    return null;
  }
}
