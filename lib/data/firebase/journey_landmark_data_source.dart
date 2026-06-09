import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/journey_landmark.dart';
import '../../util/ttl_cache.dart';

class JourneyLandmarkDataSource {
  JourneyLandmarkDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'journey_landmarks';

  /// Perf: landmark catalog is static during a journey session.
  static const Duration _landmarkCacheTtl = Duration(minutes: 15);

  static String _journeyListCacheKey(String journeyId) =>
      'landmarks_journey_$journeyId';

  static String _landmarkDocCacheKey(String documentId) =>
      'landmark_doc_$documentId';

  /// Single document `journey_landmarks/{documentId}` (e.g. `journey1landmark2` for a specific SVG region).
  Future<JourneyLandmark?> getLandmark(String documentId) async {
    final id = documentId.trim();
    if (id.isEmpty) return null;

    final cached = TtlCache.read<JourneyLandmark>(
      _landmarkDocCacheKey(id),
      _landmarkCacheTtl,
    );
    if (cached != null) return cached;

    final snap = await _firestore.collection(collection).doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    if (_isSoftDeleted(data)) return null;
    final landmark = JourneyLandmark.fromFirestore(snap.id, data);
    TtlCache.write(_landmarkDocCacheKey(id), landmark);
    return landmark;
  }

  /// Landmarks for a journey, sorted by **[order]** (not document id). Order 1 = region 1.
  /// Documents with `deletedAt` set are omitted (admin soft-delete).
  Future<List<JourneyLandmark>> getLandmarksForJourney(String journeyId) async {
    final jid = journeyId.trim();
    if (jid.isEmpty) return const [];

    final cached = TtlCache.read<List<JourneyLandmark>>(
      _journeyListCacheKey(jid),
      _landmarkCacheTtl,
    );
    if (cached != null) return List<JourneyLandmark>.from(cached);

    final snap = await _firestore
        .collection(collection)
        .where('journeyId', isEqualTo: jid)
        .get();

    final list =
        snap.docs
            .where((d) => !_isSoftDeleted(d.data()))
            .map((d) => JourneyLandmark.fromFirestore(d.id, d.data()))
            .where((l) => l.order > 0)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

    TtlCache.write(_journeyListCacheKey(jid), list);
    return list;
  }

  static bool _isSoftDeleted(Map<String, dynamic> data) =>
      data['deletedAt'] != null;

  /// All landmarks for admin (includes soft-deleted rows).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getLandmarkDocsForJourneyAdmin(String journeyId) async {
    final snap = await _firestore
        .collection(collection)
        .where('journeyId', isEqualTo: journeyId)
        .get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final oa = JourneyLandmark.fromFirestore(a.id, a.data()).order;
        final ob = JourneyLandmark.fromFirestore(b.id, b.data()).order;
        return oa.compareTo(ob);
      });
    return docs;
  }

  Future<void> createLandmark({
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collection).doc(documentId).set(data);
  }

  Future<void> updateLandmark({
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(collection)
        .doc(documentId)
        .set(data, SetOptions(merge: true));
  }

  /// Soft-delete: sets [deletedAt]. Map clients hide these via [getLandmarksForJourney].
  Future<void> softDeleteLandmark(String documentId) async {
    await _firestore.collection(collection).doc(documentId).update({
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restoreLandmark(String documentId) async {
    await _firestore.collection(collection).doc(documentId).update({
      'deletedAt': FieldValue.delete(),
    });
  }
}
