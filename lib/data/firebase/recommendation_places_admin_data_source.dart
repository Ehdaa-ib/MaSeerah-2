import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/recommendation_place.dart';

/// Admin CRUD for curated places in the primary `recommendations` collection.
class RecommendationPlacesAdminDataSource {
  RecommendationPlacesAdminDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Matches production Firestore (`recommendations` collection).
  static const String collectionId = 'recommendations';

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
