import 'package:cloud_firestore/cloud_firestore.dart';

class JourneyCompletionDataSource {
  static const String _collection = 'journeyCompletions';

  /// Append-only history under the user profile (never removed by [clearCompletion]).
  static const String userCompletionHistorySubcollection = 'journeyCompletionHistory';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _docId({required String userId, required String journeyId}) =>
      '${userId}_$journeyId';

  Future<void> markCompleted({
    required String userId,
    required String journeyId,
  }) async {
    final docId = _docId(userId: userId, journeyId: journeyId);
    final mainRef = _firestore.collection(_collection).doc(docId);
    final historyRef = _firestore
        .collection('users')
        .doc(userId)
        .collection(userCompletionHistorySubcollection)
        .doc();

    final batch = _firestore.batch();
    batch.set(
      mainRef,
      {
        'userId': userId,
        'journeyId': journeyId,
        'completedAt': FieldValue.serverTimestamp(),
        // Journey was finished on the map; feedback may still be pending.
        'awaitingFeedback': true,
      },
      SetOptions(merge: true),
    );
    batch.set(historyRef, {
      'userId': userId,
      'journeyId': journeyId,
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
}

