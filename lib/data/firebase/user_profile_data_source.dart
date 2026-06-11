import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Safe profile fields on `users/{uid}` (merge updates only).
/// Does not touch subcollections (activeJourneys, journeyFeedback, etc.).
class UserProfileDataSource {
  UserProfileDataSource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Map<String, dynamic>?> getUserProfileMap(String uid) async {
    if (uid.trim().isEmpty) return null;
    final doc = await _firestore.collection('users').doc(uid.trim()).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Merge-writes editable profile fields. Preserves all other document keys.
  Future<void> mergeProfileFields({
    required String uid,
    required String username,
    required String email,
    required String phoneNumber,
    required String gender,
    required String nationality,
    DateTime? dateOfBirth,
    required String profileImageUrl,
  }) async {
    if (uid.trim().isEmpty) return;

    final payload = <String, dynamic>{
      'username': username.trim(),
      // Keep legacy `name` in sync for [AppUser] and older reads.
      'name': username.trim(),
      'email': email.trim(),
      'phoneNumber': phoneNumber.trim(),
      'gender': gender.trim(),
      'nationality': nationality.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (dateOfBirth != null) {
      payload['dateOfBirth'] = Timestamp.fromDate(
        DateTime(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day),
      );
    } else {
      payload['dateOfBirth'] = FieldValue.delete();
    }

    if (profileImageUrl.trim().isNotEmpty) {
      payload['profileImageUrl'] = profileImageUrl.trim();
    } else {
      payload['profileImageUrl'] = FieldValue.delete();
    }

    if (kDebugMode) {
      debugPrint(
        '[UserProfile] mergeProfile uid=$uid '
        'usernameLen=${username.trim().length} emailLen=${email.trim().length} '
        'hasDob=${dateOfBirth != null} profileUrlEmpty=${profileImageUrl.trim().isEmpty}',
      );
    }

    await _firestore
        .collection('users')
        .doc(uid.trim())
        .set(payload, SetOptions(merge: true));

    if (kDebugMode) {
      debugPrint('[UserProfile] Firestore mergeProfile success uid=$uid');
    }
  }
}
