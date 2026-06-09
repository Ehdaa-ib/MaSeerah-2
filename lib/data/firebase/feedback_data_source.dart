import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'landmark_memory_data_source.dart';
import '../../model/feedback.dart';
import '../../util/journey_history_scope.dart';
import '../../util/ttl_cache.dart';

/// Wraps cached feedback lookup so "no feedback" differs from cache miss.
class _FeedbackLookupCache {
  const _FeedbackLookupCache(this.entry);
  final FeedbackEntry? entry;
}

class FeedbackDataSource {
  static const String _collection = 'feedback';

  static const Duration _instanceFeedbackCacheTtl = Duration(minutes: 5);

  static String _instanceFeedbackCacheKey(String uid, String instanceId) =>
      'feedback_instance_${uid}_$instanceId';

  /// Mirror of [feedback] under `users/{userId}/…` for profile history (same doc id).
  static const String userFeedbackSubcollection = 'journeyFeedback';

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
    return FeedbackEntry.fromMap(
      Map<String, dynamic>.from(snap.docs.first.data()),
    );
  }

  Future<List<FeedbackEntry>> _loadAllForUser(String uid) async {
    final byKey = <String, FeedbackEntry>{};

    void addFromData(Map<String, dynamic> data, {String? docId}) {
      final entry = FeedbackEntry.fromMap(data);
      if (entry.userId.trim() != uid) return;
      final key =
          docId ??
          '${entry.journeyId}_${entry.createdAt?.millisecondsSinceEpoch ?? 0}';
      byKey[key] = entry;
    }

    try {
      final root = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in root.docs) {
        addFromData(doc.data(), docId: doc.id);
      }
    } catch (_) {}

    try {
      final profileSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(userFeedbackSubcollection)
          .get();
      for (final doc in profileSnap.docs) {
        addFromData(doc.data(), docId: 'profile_${doc.id}');
      }
    } catch (_) {}

    return byKey.values.toList();
  }

  static bool _feedbackBelongsToJourney(
    String storedJourneyId,
    Set<String> tryIds,
  ) {
    if (storedJourneyId.trim().isEmpty || tryIds.isEmpty) return false;
    final storedVariants = LandmarkMemoryDataSource.journeyIdVariants(
      storedJourneyId,
    );
    for (final x in storedVariants) {
      if (tryIds.contains(x)) return true;
      final cx = x.replaceAll('_', '').toLowerCase();
      for (final y in tryIds) {
        if (y.replaceAll('_', '').toLowerCase() == cx) return true;
      }
    }
    return false;
  }

  static FeedbackEntry? _pickFeedbackForPlaythrough({
    required List<FeedbackEntry> candidates,
    String? userJourneyId,
    DateTime? afterExclusive,
    DateTime? beforeExclusive,
    bool requireTimeWindow = false,
  }) {
    if (candidates.isEmpty) return null;

    final scoped = userJourneyId?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      final byScope = candidates
          .where((e) => (e.userJourneyId ?? '').trim() == scoped)
          .toList();
      if (byScope.isNotEmpty) {
        byScope.sort((a, b) {
          final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return tb.compareTo(ta);
        });
        return byScope.first;
      }
      if (requireTimeWindow) return null;
    }

    final inWindow = candidates.where((e) {
      return JourneyHistoryScope.timestampInPlaythroughWindow(
        timestamp: e.createdAt,
        afterExclusive: afterExclusive,
        beforeExclusive: beforeExclusive,
      );
    }).toList();

    if (requireTimeWindow) {
      if (inWindow.isEmpty) return null;
      inWindow.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return inWindow.first;
    }

    final pool = inWindow.isNotEmpty ? inWindow : candidates;
    pool.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return pool.first;
  }

  /// Strict: feedback for one playthrough ([userJourneyId] / completion history doc id).
  Future<FeedbackEntry?> findForInstance({
    required String userId,
    required String userJourneyId,
    String? legacyCatalogJourneyId,
    DateTime? legacyAfterExclusive,
    DateTime? legacyBeforeExclusive,
  }) async {
    final uid = userId.trim();
    final instanceId = userJourneyId.trim();
    if (uid.isEmpty || instanceId.isEmpty) return null;

    final cacheKey = _instanceFeedbackCacheKey(uid, instanceId);
    final cached = TtlCache.read<_FeedbackLookupCache>(
      cacheKey,
      _instanceFeedbackCacheTtl,
    );
    if (cached != null) return cached.entry;

    if (LandmarkMemoryDataSource.isCatalogJourneyDocId(
      instanceId,
      catalogJourneyId: legacyCatalogJourneyId,
    )) {
      if (kDebugMode) {
        debugPrint('[Feedback] rejected catalog id as instance: $instanceId');
      }
      return null;
    }

    FeedbackEntry? match;

    void consider(FeedbackEntry? entry) {
      if (entry == null) return;
      final onDoc = (entry.userJourneyId ?? '').trim();
      if (onDoc.isNotEmpty) {
        if (onDoc != instanceId) return;
      } else {
        return;
      }
      if (match == null) {
        match = entry;
        return;
      }
      final ta = entry.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = match!.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (ta.isAfter(tb)) match = entry;
    }

    try {
      final profileSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(userFeedbackSubcollection)
          .where('userJourneyId', isEqualTo: instanceId)
          .limit(5)
          .get();
      for (final doc in profileSnap.docs) {
        consider(FeedbackEntry.fromMap(doc.data()));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Feedback] profile instance query: $e');
    }

    try {
      final rootSnap = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: uid)
          .where('userJourneyId', isEqualTo: instanceId)
          .limit(5)
          .get();
      for (final doc in rootSnap.docs) {
        consider(FeedbackEntry.fromMap(doc.data()));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Feedback] root instance query: $e');
    }

    TtlCache.write(cacheKey, _FeedbackLookupCache(match));

    if (kDebugMode) {
      debugPrint(
        '[Feedback] findForInstance userId=$uid userJourneyId=$instanceId '
        'found=${match != null}',
      );
    }
    return match;
  }

  /// Resolves feedback for one profile playthrough (catalog journey + optional scope ids / time window).
  Future<FeedbackEntry?> findForJourney({
    required String userId,
    required String journeyId,
    String? userJourneyId,
    DateTime? feedbackAfterExclusive,
    DateTime? feedbackBeforeExclusive,
    bool scopedToPlaythrough = false,
  }) async {
    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) return null;

    final tryIds = LandmarkMemoryDataSource.journeyIdVariants(jid);
    final all = await _loadAllForUser(uid);
    final candidates = all
        .where((e) => _feedbackBelongsToJourney(e.journeyId, tryIds))
        .toList();

    final requireTimeWindow =
        scopedToPlaythrough ||
        feedbackAfterExclusive != null ||
        feedbackBeforeExclusive != null;

    return _pickFeedbackForPlaythrough(
      candidates: candidates,
      userJourneyId: userJourneyId,
      afterExclusive: feedbackAfterExclusive,
      beforeExclusive: feedbackBeforeExclusive,
      requireTimeWindow: requireTimeWindow,
    );
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

  Future<String> _uploadOne({
    required String userId,
    required String journeyId,
    required XFile file,
    required int index,
  }) async {
    final ext = _extensionFromPath(file.path);
    final name = '${DateTime.now().microsecondsSinceEpoch}_$index$ext';
    final ref = _storage
        .ref()
        .child('feedbackPhotos')
        .child(userId)
        .child(journeyId)
        .child(name);
    final metadata = SettableMetadata(
      contentType: _contentTypeForPath(file.path),
    );

    try {
      final UploadTask task;
      if (!kIsWeb && file.path.isNotEmpty) {
        task = ref.putFile(File(file.path), metadata);
      } else {
        final bytes = await file.readAsBytes();
        task = ref.putData(bytes, metadata);
      }
      final snapshot = await task;
      return await snapshot.ref.getDownloadURL();
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

  Future<List<String>> uploadPhotos({
    required String userId,
    required String journeyId,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) return const [];

    return Future.wait(
      files.asMap().entries.map(
        (e) => _uploadOne(
          userId: userId,
          journeyId: journeyId,
          file: e.value,
          index: e.key,
        ),
      ),
    );
  }

  Future<void> create({required FeedbackEntry entry}) async {
    final data = <String, dynamic>{
      'userId': entry.userId,
      'journeyId': entry.journeyId,
      'overallRating': entry.overallRating,
      'contentRating': entry.contentRating,
      'recommendationRating': entry.recommendationRating,
      'challengeRating': entry.challengeRating,
      'overallComment': entry.overallComment,
      'photos': entry.photos,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (entry.userJourneyId != null && entry.userJourneyId!.trim().isNotEmpty) {
      data['userJourneyId'] = entry.userJourneyId!.trim();
    }

    final rootRef = _firestore.collection(_collection).doc();
    final profileRef = _firestore
        .collection('users')
        .doc(entry.userId)
        .collection(userFeedbackSubcollection)
        .doc(rootRef.id);

    final batch = _firestore.batch();
    batch.set(rootRef, data);
    batch.set(profileRef, data);
    await batch.commit();
    final uj = entry.userJourneyId?.trim();
    if (uj != null && uj.isNotEmpty) {
      TtlCache.invalidate('feedback_instance_${entry.userId.trim()}_$uj');
    }
  }
}
