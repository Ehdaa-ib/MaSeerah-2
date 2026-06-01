import 'package:cloud_firestore/cloud_firestore.dart';

import 'landmark_memory_data_source.dart';

/// After feedback, user must purchase again. Stored under `users/{uid}/journeyPurchaseGate/{journeyId}`.
/// Cleared when a new payment succeeds (same as clearing [journeyCompletions] gate).
class JourneyRepurchaseGateDataSource {
  static const String _subcollection = 'journeyPurchaseGate';

  final FirebaseFirestore _firestore;

  JourneyRepurchaseGateDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> setRequiresRepurchase({
    required String userId,
    required String journeyId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection(_subcollection)
        .doc(journeyId)
        .set({
      'requiresNewPurchase': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> clearRepurchaseGate({
    required String userId,
    required String journeyId,
  }) async {
    for (final id in LandmarkMemoryDataSource.journeyIdVariants(journeyId)) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection(_subcollection)
          .doc(id)
          .delete();
    }
  }

  Future<bool> requiresNewPurchase({
    required String userId,
    required String journeyId,
  }) async {
    for (final id in LandmarkMemoryDataSource.journeyIdVariants(journeyId)) {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection(_subcollection)
          .doc(id)
          .get();
      if (doc.exists && doc.data()?['requiresNewPurchase'] == true) {
        return true;
      }
    }
    return false;
  }
}
