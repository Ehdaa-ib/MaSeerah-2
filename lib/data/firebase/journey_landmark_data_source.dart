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
    return JourneyLandmark.fromFirestore(snap.id, snap.data()!);
  }

  /// Landmarks for a journey, sorted by **[order]** (not document id). Order 1 = region 1.
  Future<List<JourneyLandmark>> getLandmarksForJourney(String journeyId) async {
    final snap = await _firestore
        .collection(collection)
        .where('journeyId', isEqualTo: journeyId)
        .get();

    final list = snap.docs
        .map((d) => JourneyLandmark.fromFirestore(d.id, d.data()))
        .where((l) => l.order > 0)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    return list;
  }
}
