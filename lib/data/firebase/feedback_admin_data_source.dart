import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/validators.dart';
import '../../model/feedback.dart';

/// Admin-only access to `feedback` (requires admin email or `users.role == admin`).
class FeedbackAdminDataSource {
  FeedbackAdminDataSource({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'feedback';

  Future<List<FeedbackAdminRow>> fetchAll() async {
    final snap = await _db.collection(_collection).get();
    final userIds = snap.docs
        .map((d) => (d.data()['userId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final userNames = await _loadUserNames(userIds);
    final userEmails = await _loadUserEmails(userIds);

    final rows = snap.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      final entry = FeedbackEntry.fromMap(data);
      return FeedbackAdminRow(
        documentId: d.id,
        entry: entry,
        userDisplayName: userNames[entry.userId],
        userEmail: userEmails[entry.userId],
      );
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

  Future<Map<String, String>> _loadUserNames(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final out = <String, String>{};
    final ids = userIds.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final name = (doc.data()['name'] as String?)?.trim();
        out[doc.id] = (name != null && name.isNotEmpty) ? name : doc.id;
      }
    }
    return out;
  }

  Future<Map<String, String>> _loadUserEmails(Set<String> userIds) async {
    if (userIds.isEmpty) return {};
    final out = <String, String>{};
    final ids = userIds.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final email = (doc.data()['email'] as String?)?.trim() ?? '';
        if (email.isNotEmpty && Validators.validateEmail(email)) {
          out[doc.id] = email;
        }
      }
    }
    return out;
  }

  /// Customer email from `users/{userId}.email` only (never userId / uid as address).
  Future<String?> fetchUserEmail(String userId) async {
    final id = userId.trim();
    if (id.isEmpty || id.contains('@')) return null;
    final doc = await _db.collection('users').doc(id).get();
    if (!doc.exists) return null;
    final email = (doc.data()?['email'] as String?)?.trim() ?? '';
    if (email.isEmpty || !Validators.validateEmail(email)) return null;
    if (email.toLowerCase() == id.toLowerCase()) return null;
    return email;
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
      txn.update(ref, {
        'adminResponses': next,
        'adminResponse': trimmed,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class FeedbackAdminRow {
  final String documentId;
  final FeedbackEntry entry;
  final String? userDisplayName;
  final String? userEmail;

  FeedbackAdminRow({
    required this.documentId,
    required this.entry,
    this.userDisplayName,
    this.userEmail,
  });
}
