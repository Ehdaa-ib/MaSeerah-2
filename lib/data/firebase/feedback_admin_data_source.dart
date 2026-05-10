import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/feedback.dart';

/// Admin-only access to `feedback` (requires matching Firestore rules + admin email).
class FeedbackAdminDataSource {
  FeedbackAdminDataSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'feedback';

  Future<List<FeedbackAdminRow>> fetchAll() async {
    final snap = await _db.collection(_collection).get();
    final rows = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      final entry = FeedbackEntry.fromMap(data);
      return FeedbackAdminRow(documentId: d.id, entry: entry);
    }).toList();
    rows.sort((a, b) {
      final da = a.entry.createdAt;
      final db = b.entry.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return rows;
  }

  Future<void> appendAdminResponse({
    required String feedbackDocumentId,
    required String message,
    required String adminEmail,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    final ref = _db.collection(_collection).doc(feedbackDocumentId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        throw StateError('Feedback document not found');
      }
      final prev = (snap.data()?['adminResponses'] as List?) ?? [];
      final next = [
        ...prev,
        {
          'message': trimmed,
          'adminEmail': adminEmail.trim(),
          'respondedAt': FieldValue.serverTimestamp(),
        },
      ];
      txn.update(ref, {'adminResponses': next});
    });
  }
}

class FeedbackAdminRow {
  final String documentId;
  final FeedbackEntry entry;

  FeedbackAdminRow({
    required this.documentId,
    required this.entry,
  });
}
