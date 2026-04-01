import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../model/feedback.dart';

class FeedbackDataSource {
  static const String _collection = 'feedback';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<FeedbackEntry?> getByUserAndJourney({
    required String userId,
    required String journeyId,
  }) async {
    final snap = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('journeyId', isEqualTo: journeyId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return FeedbackEntry.fromMap(Map<String, dynamic>.from(snap.docs.first.data()));
  }

  Future<List<String>> uploadPhotos({
    required String userId,
    required String journeyId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return const [];

    final urls = <String>[];
    for (final f in files) {
      try {
        final name = DateTime.now().microsecondsSinceEpoch.toString();
        final ref = _storage
            .ref()
            .child('feedbackPhotos')
            .child(userId)
            .child(journeyId)
            .child('$name.jpg');

        final snapshot = await ref.putFile(
          f,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final url = await snapshot.ref.getDownloadURL();
        urls.add(url);
      } on FirebaseException catch (e) {
        final code = e.code;
        if (code == 'unauthorized' || code == 'permission-denied') {
          throw Exception(
            'Photo upload blocked by Storage rules. Deploy `storage.rules` and ensure you are signed in.',
          );
        }
        if (code == 'object-not-found') {
          throw Exception(
            'Upload failed: Storage object not found. Ensure Firebase Storage is enabled in Firebase Console and the app uses the correct project/bucket.',
          );
        }
        throw Exception('Photo upload failed ($code): ${e.message ?? ''}'.trim());
      }
    }
    return urls;
  }

  Future<void> create({
    required FeedbackEntry entry,
  }) async {
    await _firestore.collection(_collection).add({
      ...entry.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

