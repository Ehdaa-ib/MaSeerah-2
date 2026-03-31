import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../model/feedback.dart';

class FeedbackDataSource {
  static const String _collection = 'feedback';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String docIdFor({required String userId, required String journeyId}) =>
      '${userId}_$journeyId';

  Future<FeedbackEntry?> getByUserAndJourney({
    required String userId,
    required String journeyId,
  }) async {
    final docId = docIdFor(userId: userId, journeyId: journeyId);
    final doc = await _firestore.collection(_collection).doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return FeedbackEntry.fromMap(Map<String, dynamic>.from(doc.data()!));
  }

  Future<List<String>> uploadPhotos({
    required String userId,
    required String journeyId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return const [];

    final urls = <String>[];
    for (final f in files) {
      final name = DateTime.now().microsecondsSinceEpoch.toString();
      final ref = _storage
          .ref()
          .child('feedbackPhotos')
          .child(userId)
          .child(journeyId)
          .child('$name.jpg');

      await ref.putFile(f);
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> createOnce({
    required FeedbackEntry entry,
  }) async {
    final docId = docIdFor(userId: entry.userId, journeyId: entry.journeyId);
    final docRef = _firestore.collection(_collection).doc(docId);

    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(docRef);
      if (existing.exists) {
        throw Exception('Feedback already submitted for this journey.');
      }
      tx.set(docRef, {
        ...entry.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

