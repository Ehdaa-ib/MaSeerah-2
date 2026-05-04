import 'package:cloud_firestore/cloud_firestore.dart';

/// In-progress journey state under `users/{userId}/activeJourneys/{journeyId}`.
class JourneyProgressDataSource {
  static const String _subcollection = 'activeJourneys';

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
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return;
    final jid = journeyId.trim();
    await _col(userId).doc(jid).set(
      {
        'userId': userId.trim(),
        'journeyId': jid,
        'journeyTitle': journeyTitle.trim().isEmpty ? 'Journey' : journeyTitle.trim(),
        'landmarksJourneyId': landmarksJourneyId.trim(),
        'catalogJourneyId': catalogJourneyId?.trim(),
        'currentRegion': currentRegion,
        'qubaChallengeCompleted': qubaChallengeCompleted,
        'lastRegionChallengeCompleted': lastRegionChallengeCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> delete({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return;
    await _col(userId).doc(journeyId.trim()).delete();
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
  });

  final String journeyId;
  final String journeyTitle;
  final String landmarksJourneyId;
  final String? catalogJourneyId;
  final int currentRegion;
  final bool qubaChallengeCompleted;
  final bool lastRegionChallengeCompleted;
  final int updatedAtMillis;

  static ActiveJourneyProgress? fromMap(String docId, Map<String, dynamic> d) {
    final journeyId = (d['journeyId'] as String?)?.trim();
    final jid = (journeyId != null && journeyId.isNotEmpty) ? journeyId : docId.trim();
    if (jid.isEmpty) return null;
    final title = (d['journeyTitle'] as String?)?.trim();
    final lm = (d['landmarksJourneyId'] as String?)?.trim();
    if (lm == null || lm.isEmpty) return null;
    final region = _readInt(d['currentRegion']) ?? 1;
    final updated = d['updatedAt'];
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
    );
  }

  static int? _readInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}
