import 'package:cloud_firestore/cloud_firestore.dart';

class JourneyCompletionDataSource {
  static const String _collection = 'journeyCompletions';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _docId({required String userId, required String journeyId}) =>
      '${userId}_$journeyId';

  Future<void> markCompleted({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    await _firestore.collection(_collection).doc(docId).set({
      'userId': userId,
      'journeyId': journeyId,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isCompleted({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    final doc = await _firestore.collection(_collection).doc(docId).get();
    return doc.exists;
  }
}

