import 'package:cloud_firestore/cloud_firestore.dart';

/// One playthrough of a catalog journey — id is the `journeyHistory` / completion history doc id.
class JourneyInstanceDataSource {
  static const String journeyHistorySubcollection = 'journeyHistory';

  final FirebaseFirestore _firestore;

  JourneyInstanceDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _historyDoc(String userId, String instanceId) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection(journeyHistorySubcollection)
          .doc(instanceId);

  /// Creates a new journey instance document; returns its id ([userJourneyId]).
  Future<String> createInstance({
    required String userId,
    required String catalogJourneyId,
    required String journeyTitle,
  }) async {
    final uid = userId.trim();
    final catalog = catalogJourneyId.trim();
    if (uid.isEmpty || catalog.isEmpty) {
      throw StateError('userId and catalogJourneyId are required.');
    }
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection(journeyHistorySubcollection)
        .doc();
    await ref.set({
      'userId': uid,
      'journeyId': catalog,
      'userJourneyId': ref.id,
      'journeyTitle': journeyTitle.trim().isEmpty ? 'Journey' : journeyTitle.trim(),
      'startedAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> touchInstance({
    required String userId,
    required String userJourneyId,
  }) async {
    final uid = userId.trim();
    final iid = userJourneyId.trim();
    if (uid.isEmpty || iid.isEmpty) return;
    await _historyDoc(uid, iid).set(
      {
        'userJourneyId': iid,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> markInstanceCompleted({
    required String userId,
    required String userJourneyId,
    required String catalogJourneyId,
  }) async {
    final uid = userId.trim();
    final iid = userJourneyId.trim();
    if (uid.isEmpty || iid.isEmpty) return;
    await _historyDoc(uid, iid).set(
      {
        'userId': uid,
        'journeyId': catalogJourneyId.trim(),
        'userJourneyId': iid,
        'completedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
