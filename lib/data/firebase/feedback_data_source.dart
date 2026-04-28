import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }

  static String _contentTypeForPath(String path) {
    switch (_extensionFromPath(path)) {
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<List<String>> uploadPhotos({
    required String userId,
    required String journeyId,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return const [];

    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final x = files[i];
      try {
        final bytes = await x.readAsBytes();
        final ext = _extensionFromPath(x.path);
        final name =
            '${DateTime.now().microsecondsSinceEpoch}_$i$ext';
        final ref = _storage
            .ref()
            .child('feedbackPhotos')
            .child(userId)
            .child(journeyId)
            .child(name);

        final snapshot = await ref.putData(
          bytes,
          SettableMetadata(contentType: _contentTypeForPath(x.path)),
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
    // Explicit map so optional ratings (0) are always sent; avoids rules
    // treating omitted fields as missing.
    await _firestore.collection(_collection).add({
      'userId': entry.userId,
      'journeyId': entry.journeyId,
      'overallRating': entry.overallRating,
      'contentRating': entry.contentRating,
      'recommendationRating': entry.recommendationRating,
      'challengeRating': entry.challengeRating,
      'overallComment': entry.overallComment,
      'photos': entry.photos,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
