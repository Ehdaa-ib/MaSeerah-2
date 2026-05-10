import 'package:cloud_firestore/cloud_firestore.dart';

import 'recommendation_places_data_source.dart';
import '../../model/recommendation_place.dart';

/// Writes to `recommendation_places` only (same collection the app reads first).
/// Preserves Firestore field shape expected by [RecommendationPlace], including `images`.
class RecommendationPlacesAdminDataSource {
  RecommendationPlacesAdminDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static String get collectionId => RecommendationPlacesDataSource.collectionName;

  Future<List<RecommendationPlace>> fetchAll() async {
    final snap = await _db.collection(collectionId).get();
    final out = <RecommendationPlace>[];
    for (var i = 0; i < snap.docs.length; i++) {
      final p = RecommendationPlace.fromDoc(snap.docs[i], fallbackOrder: i + 1);
      if (p != null) out.add(p);
    }
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  Future<void> upsert({
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(collectionId).doc(documentId).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<void> delete(String documentId) async {
    await _db.collection(collectionId).doc(documentId).delete();
  }

  Future<Map<String, dynamic>?> rawDocument(String documentId) async {
    final d = await _db.collection(collectionId).doc(documentId).get();
    if (!d.exists || d.data() == null) return null;
    return Map<String, dynamic>.from(d.data()!);
  }
}
