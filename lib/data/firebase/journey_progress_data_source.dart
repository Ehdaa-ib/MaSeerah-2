import 'package:cloud_firestore/cloud_firestore.dart';

import '../../util/ttl_cache.dart';

/// Distinguishes cache miss from "no saved progress".
class _ProgressLookupCache {
  const _ProgressLookupCache(this.progress);
  final ActiveJourneyProgress? progress;
}

/// In-progress journey state under `users/{userId}/activeJourneys/{journeyId}`.
///
/// Optional field `hasSeenHowToPlay` (bool) stores whether the user has completed the
/// first-time "How to play" instructions for this journey (same document as map progress).
class JourneyProgressDataSource {
  static const String activeJourneysSubcollection = 'activeJourneys';
  static const String _subcollection = activeJourneysSubcollection;

  /// Perf: dedupe progress reads during map/purchase flows (invalidated on writes).
  static const Duration _progressCacheTtl = Duration(minutes: 2);

  static String _progressCacheKey(String uid, String journeyId) =>
      'progress_${uid}_$journeyId';

  static void _invalidateProgressCacheForUser(String uid) {
    TtlCache.invalidate('progress_${uid.trim()}_');
  }

  final FirebaseFirestore _firestore;

  JourneyProgressDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String userId) =>
      _firestore.collection('users').doc(userId).collection(_subcollection);

  /// Latest saved progress for [journeyId], or null if none.
  Future<ActiveJourneyProgress?> get({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return null;
    final doc = await _col(userId).doc(journeyId.trim()).get();
    if (!doc.exists || doc.data() == null) return null;
    return ActiveJourneyProgress.fromMap(journeyId.trim(), doc.data()!);
  }

  /// Source-of-truth lookup used by both Active Journeys and Journey Details.
  ///
  /// Some older flows may store progress under a slightly different id. This method:
  /// - first tries doc id == [journeyId]
  /// - then tries a normalized id (removing `_`)
  /// - then queries by `catalogJourneyId == journeyId`
  Future<ActiveJourneyProgress?> getUserJourneyProgress({
    required String userId,
    required String journeyId,
  }) async {
    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) return null;

    final cacheKey = _progressCacheKey(uid, jid);
    final cached = TtlCache.read<_ProgressLookupCache>(
      cacheKey,
      _progressCacheTtl,
    );
    if (cached != null) return cached.progress;

    // 1) Direct doc id match (current standard).
    final direct = await get(userId: uid, journeyId: jid);
    if (direct != null) {
      _cacheProgressLookup(uid, jid, direct);
      return direct;
    }

    // 2) Fallback: normalized id without underscores.
    final normalized = jid.replaceAll('_', '');
    if (normalized.isNotEmpty && normalized != jid) {
      final normDoc = await get(userId: uid, journeyId: normalized);
      if (normDoc != null) {
        _cacheProgressLookup(uid, jid, normDoc);
        return normDoc;
      }
    }

    // 3) Fallback: query by `catalogJourneyId`.
    final q = await _col(
      uid,
    ).where('catalogJourneyId', isEqualTo: jid).limit(1).get();
    if (q.docs.isEmpty) {
      TtlCache.write(cacheKey, const _ProgressLookupCache(null));
      return null;
    }
    final d = q.docs.first;
    final resolved = ActiveJourneyProgress.fromMap(d.id, d.data());
    TtlCache.write(cacheKey, _ProgressLookupCache(resolved));
    return resolved;
  }

  void _cacheProgressLookup(
    String uid,
    String jid,
    ActiveJourneyProgress? progress,
  ) {
    TtlCache.write(_progressCacheKey(uid, jid), _ProgressLookupCache(progress));
  }

  Future<List<ActiveJourneyProgress>> listAll({required String userId}) async {
    if (userId.trim().isEmpty) return const [];
    final snap = await _col(userId.trim()).get();
    final out = <ActiveJourneyProgress>[];
    for (final d in snap.docs) {
      final parsed = ActiveJourneyProgress.fromMap(d.id, d.data());
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
    return out;
  }

  Stream<List<ActiveJourneyProgress>> streamAll({required String userId}) {
    if (userId.trim().isEmpty) {
      return Stream.value(const <ActiveJourneyProgress>[]);
    }
    return _col(userId).snapshots().map((snap) {
      final out = <ActiveJourneyProgress>[];
      for (final d in snap.docs) {
        final data = d.data();
        final parsed = ActiveJourneyProgress.fromMap(d.id, data);
        if (parsed != null) out.add(parsed);
      }
      out.sort((a, b) => b.updatedAtMillis.compareTo(a.updatedAtMillis));
      return out;
    });
  }

  Future<void> upsert({
    required String userId,
    required String journeyId,
    required String journeyTitle,
    required String landmarksJourneyId,
    String? catalogJourneyId,
    required int currentRegion,
    required bool qubaChallengeCompleted,
    required bool lastRegionChallengeCompleted,

    /// When null, existing `hasSeenHowToPlay` in Firestore is left unchanged (map saves must not reset it).
    bool? hasSeenHowToPlay,
    String? userJourneyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return;
    final jid = journeyId.trim();
    final payload = <String, dynamic>{
      'userId': userId.trim(),
      'journeyId': jid,
      'journeyTitle': journeyTitle.trim().isEmpty
          ? 'Journey'
          : journeyTitle.trim(),
      'landmarksJourneyId': landmarksJourneyId.trim(),
      'catalogJourneyId': catalogJourneyId?.trim(),
      'currentRegion': currentRegion,
      'qubaChallengeCompleted': qubaChallengeCompleted,
      'lastRegionChallengeCompleted': lastRegionChallengeCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (hasSeenHowToPlay != null) {
      payload['hasSeenHowToPlay'] = hasSeenHowToPlay;
    }
    final uj = userJourneyId?.trim();
    if (uj != null && uj.isNotEmpty) {
      payload['userJourneyId'] = uj;
    }
    await _col(userId).doc(jid).set(payload, SetOptions(merge: true));
    _invalidateProgressCacheForUser(userId.trim());
  }

  /// Merges only the how-to-play flag (and timestamp). Safe when other fields are written separately.
  Future<void> mergeHasSeenHowToPlay({
    required String userId,
    required String journeyId,
    required bool value,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return;
    await _col(userId).doc(journeyId.trim()).set({
      'hasSeenHowToPlay': value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _invalidateProgressCacheForUser(userId.trim());
  }

  Future<void> delete({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return;
    await _col(userId).doc(journeyId.trim()).delete();
    _invalidateProgressCacheForUser(userId.trim());
  }
}

class ActiveJourneyProgress {
  ActiveJourneyProgress({
    required this.journeyId,
    required this.journeyTitle,
    required this.landmarksJourneyId,
    this.catalogJourneyId,
    required this.currentRegion,
    required this.qubaChallengeCompleted,
    required this.lastRegionChallengeCompleted,
    required this.updatedAtMillis,
    this.hasSeenHowToPlay = false,

    /// [users/uid/activeJourneys] document id (may differ from [catalogJourneyId] for legacy rows).
    required this.firestoreDocId,
    this.userJourneyId,
  });

  final String journeyId;
  final String journeyTitle;
  final String landmarksJourneyId;
  final String? catalogJourneyId;
  final int currentRegion;
  final bool qubaChallengeCompleted;
  final bool lastRegionChallengeCompleted;
  final int updatedAtMillis;
  final bool hasSeenHowToPlay;
  final String firestoreDocId;

  /// Unique playthrough id — same as `users/{uid}/journeyHistory/{userJourneyId}` doc id.
  final String? userJourneyId;

  static ActiveJourneyProgress? fromMap(String docId, Map<String, dynamic> d) {
    final journeyId = (d['journeyId'] as String?)?.trim();
    final jid = (journeyId != null && journeyId.isNotEmpty)
        ? journeyId
        : docId.trim();
    if (jid.isEmpty) return null;
    final title = (d['journeyTitle'] as String?)?.trim();
    final lm = (d['landmarksJourneyId'] as String?)?.trim();
    if (lm == null || lm.isEmpty) return null;
    final region = _readInt(d['currentRegion']) ?? 1;
    final updated = d['updatedAt'] ?? d['lastUpdatedAt'];
    int updatedMs = 0;
    if (updated is Timestamp) {
      updatedMs = updated.millisecondsSinceEpoch;
    }
    return ActiveJourneyProgress(
      journeyId: jid,
      journeyTitle: (title != null && title.isNotEmpty) ? title : 'Journey',
      landmarksJourneyId: lm,
      catalogJourneyId: (d['catalogJourneyId'] as String?)?.trim(),
      currentRegion: region.clamp(1, 99),
      qubaChallengeCompleted: d['qubaChallengeCompleted'] == true,
      lastRegionChallengeCompleted: d['lastRegionChallengeCompleted'] == true,
      updatedAtMillis: updatedMs,
      hasSeenHowToPlay: d['hasSeenHowToPlay'] == true,
      firestoreDocId: docId.trim(),
      userJourneyId: (d['userJourneyId'] as String?)?.trim(),
    );
  }

  static int? _readInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}
