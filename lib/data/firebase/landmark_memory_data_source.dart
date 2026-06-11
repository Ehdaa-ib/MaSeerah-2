import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/landmark_memory.dart';
import '../../util/ttl_cache.dart';

/// Landmark memories under `users/{userId}/journeyHistory/{journeyId}/landmarkMemories/{memoryId}`.
class LandmarkMemoryDataSource {
  static const String journeyHistorySubcollection = 'journeyHistory';
  static const String memoriesSubcollection = 'landmarkMemories';

  /// Perf: avoid repeat collection-group reads during one session.
  static const Duration _memoriesCacheTtl = Duration(minutes: 5);

  static String _userMemoriesCacheKey(String uid) => 'memories_user_$uid';

  static String _instanceMemoriesCacheKey(String uid, String instanceId) =>
      'memories_instance_${uid}_$instanceId';

  static void invalidateMemoriesCacheForUser(String userId) {
    final uid = userId.trim();
    if (uid.isEmpty) return;
    TtlCache.invalidate('memories_user_$uid');
    TtlCache.invalidate('memories_instance_$uid');
  }

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  LandmarkMemoryDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  DocumentReference<Map<String, dynamic>> _journeyHistoryDoc(
    String userId,
    String journeyId,
  ) => _firestore
      .collection('users')
      .doc(userId)
      .collection(journeyHistorySubcollection)
      .doc(journeyId);

  CollectionReference<Map<String, dynamic>> _memoriesCol(
    String userId,
    String journeyId,
  ) => _journeyHistoryDoc(userId, journeyId).collection(memoriesSubcollection);

  /// Aligns catalog id with progress / purchase screen (`journey1` → `journey_1`).
  static String normalizeCatalogJourneyId({
    String? catalogJourneyId,
    String? landmarksJourneyId,
  }) {
    final c = catalogJourneyId?.trim();
    if (c != null && c.isNotEmpty) return c;
    final lm = landmarksJourneyId?.trim() ?? '';
    if (lm.isEmpty) return '';
    final m = RegExp(r'^journey(\d+)$').firstMatch(lm);
    if (m != null) return 'journey_${m.group(1)}';
    return lm;
  }

  static String _extensionFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot <= 0 || dot >= path.length - 1) return '.jpg';
    return path.substring(dot).toLowerCase();
  }

  static String _extensionFromFile(XFile file, {required bool isVideo}) {
    if (isVideo) {
      final p = _extensionFromPath(file.path);
      return p == '.jpg' ? '.mp4' : p;
    }
    final fromPath = _extensionFromPath(file.path);
    if (file.path.contains('.')) return fromPath;
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.contains('png')) return '.png';
    if (mime.contains('webp')) return '.webp';
    if (mime.contains('heic') || mime.contains('heif')) return '.heic';
    return '.jpg';
  }

  static bool _isVideoFile(XFile file) {
    final mime = file.mimeType?.toLowerCase() ?? '';
    if (mime.startsWith('video/')) return true;
    final ext = _extensionFromPath(file.path);
    return ext == '.mp4' ||
        ext == '.mov' ||
        ext == '.m4v' ||
        ext == '.avi' ||
        ext == '.mkv' ||
        ext == '.webm';
  }

  static String _contentTypeForExtension(String ext, {required bool isVideo}) {
    if (isVideo) {
      switch (ext) {
        case '.mov':
          return 'video/quicktime';
        case '.webm':
          return 'video/webm';
        default:
          return 'video/mp4';
      }
    }
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
      case '.heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static Never _throwFriendly(FirebaseException e, {required String step}) {
    final code = e.code;
    if (code == 'permission-denied' || code == 'unauthorized') {
      throw Exception(
        '$step blocked by Firebase rules. Deploy firestore.rules and storage.rules from this project, then try again.',
      );
    }
    throw Exception('$step failed: ${e.message ?? code}');
  }

  Future<List<LandmarkMemory>> _fetchMemoriesCol(
    String userId,
    String journeyDocId,
  ) async {
    final snap = await _memoriesCol(userId, journeyDocId).get();
    final out = <LandmarkMemory>[];
    for (final d in snap.docs) {
      final parsed = LandmarkMemory.fromDoc(d.id, d.data());
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) {
      final o = a.landmarkOrder.compareTo(b.landmarkOrder);
      if (o != 0) return o;
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return ta.compareTo(tb);
    });
    return out;
  }

  /// All landmark photos/videos for a user (one query when the collection-group index exists).
  Future<List<LandmarkMemory>> fetchAllMemoriesForUser(String userId) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const [];

    final cached = TtlCache.read<List<LandmarkMemory>>(
      _userMemoriesCacheKey(uid),
      _memoriesCacheTtl,
    );
    if (cached != null) return List<LandmarkMemory>.from(cached);

    try {
      final list = await _fetchAllMemoriesForUserImpl(
        uid,
      ).timeout(const Duration(seconds: 12));
      TtlCache.write(_userMemoriesCacheKey(uid), list);
      return list;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LandmarkMemory] fetchAll timed out or failed: $e');
      }
      return const [];
    }
  }

  Future<List<LandmarkMemory>> _fetchAllMemoriesForUserImpl(String uid) async {
    try {
      final snap = await _firestore
          .collectionGroup(memoriesSubcollection)
          .where('userId', isEqualTo: uid)
          .limit(250)
          .get()
          .timeout(const Duration(seconds: 8));
      return _memoriesFromQueryDocs(snap.docs);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] fetchAll collectionGroup: ${e.code} — falling back',
        );
      }
      return _fetchAllMemoriesForUserPerJourney(uid);
    }
  }

  List<LandmarkMemory> _memoriesFromQueryDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <LandmarkMemory>[];
    for (final d in docs) {
      final parsed = LandmarkMemory.fromDoc(d.id, d.data());
      if (parsed != null) out.add(parsed);
    }
    out.sort((a, b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return out;
  }

  /// Fallback when collection-group index is missing: parallel per-journey reads.
  Future<List<LandmarkMemory>> _fetchAllMemoriesForUserPerJourney(
    String uid,
  ) async {
    try {
      final histSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection(journeyHistorySubcollection)
          .get()
          .timeout(const Duration(seconds: 8));
      if (histSnap.docs.isEmpty) return const [];

      final lists = await Future.wait(
        histSnap.docs.map((hist) => _fetchMemoriesCol(uid, hist.id)),
      );
      final out = <LandmarkMemory>[];
      for (final list in lists) {
        out.addAll(list);
      }
      out.sort((a, b) {
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return out;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('[LandmarkMemory] fetchAll per-journey: ${e.code}');
      }
      return const [];
    }
  }

  /// Uploads file bytes and writes Firestore metadata. Returns download URL.
  Future<String> saveLandmarkMemory({
    required String userId,
    required String journeyId,
    required String userJourneyId,
    required String journeyTitle,
    required String landmarkId,
    required String landmarkTitle,
    required int landmarkOrder,
    required XFile file,
    required String source,
  }) async {
    final uid = userId.trim();
    final jid = normalizeCatalogJourneyId(catalogJourneyId: journeyId);
    final instanceId = userJourneyId.trim();
    if (uid.isEmpty || jid.isEmpty || instanceId.isEmpty) {
      throw StateError('Missing user, journey, or userJourneyId.');
    }

    final isVideo = _isVideoFile(file);
    final mediaType = isVideo ? 'video' : 'image';
    final ext = _extensionFromFile(file, isVideo: isVideo);
    final memoryId = _memoriesCol(uid, instanceId).doc().id;
    final storagePath = 'landmarkMemories/$uid/$instanceId/$memoryId$ext';
    final ref = _storage.ref().child(storagePath);
    final contentType = _contentTypeForExtension(ext, isVideo: isVideo);

    if (kDebugMode) {
      debugPrint(
        '[LandmarkMemory] upload start journeyId=$jid landmark=$landmarkId path=$storagePath',
      );
    }

    // Parent doc + upload in parallel to reduce wait on Next.
    try {
      final journeyTitleEn = journeyTitle.trim().isEmpty
          ? 'Journey'
          : journeyTitle.trim();
      final landmarkTitleEn = landmarkTitle.trim().isEmpty
          ? 'Landmark'
          : landmarkTitle.trim();
      final parentPayload = <String, dynamic>{
        'userId': uid,
        'journeyId': jid,
        'userJourneyId': instanceId,
        'journeyHistoryId': instanceId,
        'journeyTitle': journeyTitleEn,
        'startedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      };
      final parentFuture = _journeyHistoryDoc(
        uid,
        instanceId,
      ).set(parentPayload, SetOptions(merge: true));

      final SettableMetadata metadata = SettableMetadata(
        contentType: contentType,
      );
      final UploadTask uploadTask;
      if (!kIsWeb && file.path.isNotEmpty) {
        uploadTask = ref.putFile(File(file.path), metadata);
      } else {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) {
          throw Exception('Selected file is empty');
        }
        uploadTask = ref.putData(bytes, metadata);
      }

      await parentFuture;
      final snapshot = await uploadTask;
      final mediaUrl = await snapshot.ref.getDownloadURL();

      final batch = _firestore.batch();
      final memoryRef = _memoriesCol(uid, instanceId).doc(memoryId);
      final memoryPayload = <String, dynamic>{
        'userId': uid,
        'journeyId': jid,
        'userJourneyId': instanceId,
        'journeyHistoryId': instanceId,
        'journeyTitle': journeyTitleEn,
        'landmarkId': landmarkId.trim(),
        'landmarkName': landmarkTitleEn,
        'landmarkTitle': landmarkTitleEn,
        'landmarkOrder': landmarkOrder,
        'mediaUrl': mediaUrl,
        'imageUrl': mediaUrl,
        'mediaType': mediaType,
        'storagePath': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
        'source': source,
      };
      batch.set(memoryRef, memoryPayload);
      batch.set(_journeyHistoryDoc(uid, instanceId), {
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'memoriesCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
      await batch.commit();

      invalidateMemoriesCacheForUser(uid);

      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] saved ok memoryId=$memoryId userJourneyId=$instanceId '
          'path=users/$uid/journeyHistory/$instanceId/landmarkMemories',
        );
      }
      return mediaUrl;
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] FirebaseException ${e.code}: ${e.message}',
        );
      }
      if (e.code == 'permission-denied' || e.code == 'unauthorized') {
        _throwFriendly(e, step: 'Journey history');
      }
      _throwFriendly(e, step: isVideo ? 'Video upload' : 'Photo upload');
    }
  }

  /// True when [docId] is a catalog/template journey key (`journey_1`), not a playthrough id.
  static bool isCatalogJourneyDocId(String docId, {String? catalogJourneyId}) {
    final id = docId.trim();
    if (id.isEmpty) return true;

    final catalog = catalogJourneyId?.trim();
    if (catalog != null && catalog.isNotEmpty) {
      if (journeyIdVariants(catalog).contains(id)) return true;
    }

    // Legacy parent/history docs named after the template (not Firestore auto-ids).
    final compact = id.replaceAll('_', '').toLowerCase();
    return RegExp(r'^journey\d+$').hasMatch(compact);
  }

  /// Id aliases for one catalog journey (`journey_1`, `journey1`, …).
  static Set<String> journeyIdVariants(String journeyId) {
    final jid = journeyId.trim();
    if (jid.isEmpty) return const {};
    return {
      jid,
      normalizeCatalogJourneyId(catalogJourneyId: jid),
      jid.replaceAll('_', ''),
    }..removeWhere((e) => e.isEmpty);
  }

  static bool memoryBelongsToJourney(
    LandmarkMemory memory,
    Set<String> variants,
  ) {
    if (variants.isEmpty) return false;
    final mid = memory.journeyId.trim();
    if (mid.isEmpty) return false;
    if (variants.contains(mid)) return true;
    final normalized = normalizeCatalogJourneyId(catalogJourneyId: mid);
    if (normalized.isNotEmpty && variants.contains(normalized)) return true;
    final compact = mid.replaceAll('_', '').toLowerCase();
    return variants.any((v) => v.replaceAll('_', '').toLowerCase() == compact);
  }

  /// Strict: only photos for this playthrough ([userJourneyId] / [journeyHistoryId]).
  Future<List<LandmarkMemory>> fetchMemoriesForInstance({
    required String userId,
    required String userJourneyId,
    String? catalogJourneyIdForMisplacedDocs,
  }) async {
    final uid = userId.trim();
    final instanceId = userJourneyId.trim();
    final catalog = catalogJourneyIdForMisplacedDocs?.trim();
    if (uid.isEmpty || instanceId.isEmpty) return const [];

    final cacheKey = _instanceMemoriesCacheKey(uid, instanceId);
    final cached = TtlCache.read<List<LandmarkMemory>>(
      cacheKey,
      _memoriesCacheTtl,
    );
    if (cached != null) return List<LandmarkMemory>.from(cached);

    // Perf: reuse profile-wide fetch when already in memory.
    final fromUserCache = TtlCache.read<List<LandmarkMemory>>(
      _userMemoriesCacheKey(uid),
      _memoriesCacheTtl,
    );
    if (fromUserCache != null) {
      final filtered = fromUserCache
          .where((m) => (m.userJourneyId ?? '').trim() == instanceId)
          .toList();
      if (filtered.isNotEmpty) {
        TtlCache.write(cacheKey, filtered);
        return filtered;
      }
    }

    if (isCatalogJourneyDocId(instanceId, catalogJourneyId: catalog)) {
      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] rejected catalog id as instance: $instanceId '
          '(use completion history doc id, not journey_1)',
        );
      }
      return const [];
    }

    final byId = <String, LandmarkMemory>{};

    void addIfInstance(LandmarkMemory m, {required String source}) {
      final onDoc = (m.userJourneyId ?? '').trim();
      if (onDoc.isNotEmpty && onDoc != instanceId) {
        if (kDebugMode) {
          debugPrint(
            '[LandmarkMemory] skip $source memoryId=${m.id} '
            'storedUserJourneyId=$onDoc expected=$instanceId',
          );
        }
        return;
      }
      if (onDoc.isEmpty && source == 'misplaced-catalog') {
        return;
      }
      if (onDoc.isEmpty && source == 'instance-path') {
        return;
      }
      byId[m.id] = m;
      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] keep $source memoryId=${m.id} '
          'userJourneyId=${onDoc.isEmpty ? "(path:$instanceId)" : onDoc}',
        );
      }
    }

    // Perf: prefer one indexed collection-group query before path/misplaced fallbacks.
    try {
      final snap = await _firestore
          .collectionGroup(memoriesSubcollection)
          .where('userId', isEqualTo: uid)
          .where('userJourneyId', isEqualTo: instanceId)
          .limit(80)
          .get();
      for (final m in _memoriesFromQueryDocs(snap.docs)) {
        addIfInstance(m, source: 'collection-group');
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('[LandmarkMemory] instance group query: ${e.code}');
      }
    }

    if (byId.isEmpty) {
      try {
        final fromPath = await _fetchMemoriesCol(uid, instanceId);
        for (final m in fromPath) {
          addIfInstance(m, source: 'instance-path');
        }
      } on FirebaseException catch (e) {
        if (kDebugMode) {
          debugPrint('[LandmarkMemory] instance path $instanceId: ${e.code}');
        }
      }
    }

    // Safe fallback: docs stored under catalog path but tagged with this instance id.
    if (byId.isEmpty && catalog != null && catalog.isNotEmpty) {
      for (final docId in journeyIdVariants(catalog)) {
        try {
          final misplaced = await _fetchMemoriesCol(uid, docId);
          for (final m in misplaced) {
            final onDoc = (m.userJourneyId ?? '').trim();
            if (onDoc != instanceId) continue;
            addIfInstance(m, source: 'misplaced-catalog');
          }
        } catch (_) {}
      }
    }

    if (kDebugMode) {
      debugPrint(
        '[LandmarkMemory] fetchMemoriesForInstance userId=$uid userJourneyId=$instanceId '
        'displayed=${byId.length} ids=${byId.keys.join(",")}',
      );
    }

    final out = byId.values.toList()
      ..sort((a, b) {
        final o = a.landmarkOrder.compareTo(b.landmarkOrder);
        if (o != 0) return o;
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
    TtlCache.write(cacheKey, out);
    return out;
  }
}
