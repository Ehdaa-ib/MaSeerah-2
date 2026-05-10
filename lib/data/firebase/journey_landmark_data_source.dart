import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/journey_landmark.dart';

class JourneyLandmarkDataSource {
  JourneyLandmarkDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String collection = 'journey_landmarks';

  /// Single document `journey_landmarks/{documentId}` (e.g. `journey1landmark2` for a specific SVG region).
  Future<JourneyLandmark?> getLandmark(String documentId) async {
    final snap = await _firestore.collection(collection).doc(documentId).get();
    if (!snap.exists || snap.data() == null) return null;
    final data = snap.data()!;
    if (_isSoftDeleted(data)) return null;
    return JourneyLandmark.fromFirestore(snap.id, data);
  }

  /// Landmarks for a journey, sorted by **[order]** (not document id). Order 1 = region 1.
  /// Documents with `deletedAt` set are omitted (admin soft-delete).
  Future<List<JourneyLandmark>> getLandmarksForJourney(String journeyId) async {
    final snap = await _firestore
        .collection(collection)
        .where('journeyId', isEqualTo: journeyId)
        .get();

    final list = snap.docs
        .where((d) => !_isSoftDeleted(d.data()))
        .map((d) => JourneyLandmark.fromFirestore(d.id, d.data()))
        .where((l) => l.order > 0)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return list;
  }

  static bool _isSoftDeleted(Map<String, dynamic> data) => data['deletedAt'] != null;

  /// All landmarks for admin (includes soft-deleted rows).
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getLandmarkDocsForJourneyAdmin(
    String journeyId,
  ) async {
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
    await _firestore.collection(collection).doc(documentId).set(
          data,
          SetOptions(merge: true),
        );
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
