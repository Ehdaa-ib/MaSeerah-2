import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/firebase/feedback_data_source.dart';
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/firebase/landmark_memory_data_source.dart';
import '../../model/journey.dart';
import '../../model/landmark_memory.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/user_media_card_actions.dart';
import '../../widgets/user_media_preview_sheet.dart';
import '../faq/faqs_page.dart';
import '../journey/journey_history_memories_screen.dart';
import '../../util/journey_history_scope.dart';
import '../journey/journey_list_screen.dart';
import '../auth/login_screen.dart';
import 'landing_page.dart';
import 'edit_profile_screen.dart';
import 'profile_section_list_screen.dart';
import '../../l10n/app_localizations.dart';

const String _journeyCompletionsCollection = 'journeyCompletions';

const int _profilePreviewLimit = 5;
const double _profileSectionHeight = 160;

/// In-memory snapshot so reopening profile shows last data instantly.
class _ProfileSnapshot {
  const _ProfileSnapshot({
    required this.uid,
    required this.userName,
    required this.joinedDate,
    required this.profileImageUrl,
    required this.journeysCount,
    required this.photosCount,
    required this.userJourneys,
    required this.userFeedbacks,
    required this.userPhotos,
  });

  final String uid;
  final String userName;
  final String joinedDate;
  final String? profileImageUrl;
  final int journeysCount;
  final int photosCount;
  final List<Map<String, dynamic>> userJourneys;
  final List<Map<String, dynamic>> userFeedbacks;
  final List<Map<String, dynamic>> userPhotos;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static _ProfileSnapshot? _cachedSnapshot;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final JourneyDataSource _journeyDs = JourneyDataSource();
  final LandmarkMemoryDataSource _memoryDs = LandmarkMemoryDataSource();

  String userName = "";
  String joinedDate = "";
  String? profileImageUrl;
  int journeysCount = 0;
  int photosCount = 0;
  List<Map<String, dynamic>> userJourneys = [];
  List<Map<String, dynamic>> userFeedbacks = [];

  /// Each entry: `url` (String), optional `journeyName`, `createdAt` (DateTime?), `source` (String).
  List<Map<String, dynamic>> userPhotos = [];
  Map<String, String> _journeyNameLookup = {};

  /// Sections and stats stay in loading until Firestore profile data finishes.
  bool _isProfileDataLoading = false;

  /// True when [_cachedSnapshot] was applied on open (perf: refresh in background).
  bool _hadCachedSnapshotOnOpen = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromAuthSync();
    final uid = _auth.currentUser?.uid;
    _hadCachedSnapshotOnOpen = uid != null && _cachedSnapshot?.uid == uid;
    _isProfileDataLoading = uid != null && !_hadCachedSnapshotOnOpen;
    if (_hadCachedSnapshotOnOpen) {
      _applySnapshot(_cachedSnapshot!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadUserData());
    });
  }

  void _applySnapshot(_ProfileSnapshot s) {
    userName = s.userName;
    joinedDate = s.joinedDate;
    profileImageUrl = s.profileImageUrl;
    journeysCount = s.journeysCount;
    photosCount = s.photosCount;
    userJourneys = s.userJourneys
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    userFeedbacks = s.userFeedbacks
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    userPhotos = s.userPhotos.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _saveSnapshot(String uid) {
    _cachedSnapshot = _ProfileSnapshot(
      uid: uid,
      userName: userName,
      joinedDate: joinedDate,
      profileImageUrl: profileImageUrl,
      journeysCount: journeysCount,
      photosCount: photosCount,
      userJourneys: userJourneys
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      userFeedbacks: userFeedbacks
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      userPhotos: userPhotos.map((e) => Map<String, dynamic>.from(e)).toList(),
    );
  }

  /// Name/email from Firebase Auth — no network; shows immediately on open.
  void _hydrateFromAuthSync() {
    final u = _auth.currentUser;
    if (u == null) return;
    final fromEmail = u.email?.split('@').first;
    final dn = u.displayName?.trim();
    userName = (dn != null && dn.isNotEmpty) ? dn : (fromEmail ?? 'User');
    joinedDate = '…';
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  /// Full calendar date on profile journey and feedback cards.
  String _formatExactDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Prefer Firestore `createdAt` (user doc); fall back to legacy `joinedDate` / snake_case aliases.
  DateTime? _readJoinDateFromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v =
        data['createdAt'] ??
        data['created_at'] ??
        data['joinedDate'] ??
        data['joined_at'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  void _applyUserDocument(
    DocumentSnapshot<Map<String, dynamic>> userDoc,
    User user,
  ) {
    if (userDoc.exists) {
      final data = userDoc.data();
      final un = (data?['username'] as String?)?.trim();
      final nm = (data?['name'] as String?)?.trim();
      userName = (un != null && un.isNotEmpty)
          ? un
          : (nm != null && nm.isNotEmpty)
          ? nm
          : user.email?.split('@').first ?? 'User';
      final rawUrl = (data?['profileImageUrl'] as String?)?.trim();
      profileImageUrl = (rawUrl != null && rawUrl.isNotEmpty) ? rawUrl : null;
      final join = _readJoinDateFromUserDoc(data);
      joinedDate = join != null ? _formatDate(join) : 'Unknown';
    } else {
      userName = user.email?.split('@').first ?? 'User';
      profileImageUrl = null;
      joinedDate = 'Unknown';
    }
  }

  DateTime? _coerceToDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) {
      final t = DateTime.tryParse(v.trim());
      if (t != null) return t;
    }
    return null;
  }

  String? _photoUrlFromDoc(Map<String, dynamic> d) {
    const keys = [
      'url',
      'imageUrl',
      'downloadUrl',
      'photoUrl',
      'downloadURL',
      'imageURL',
      'src',
      'uri',
    ];
    for (final k in keys) {
      final v = d[k];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty && t.startsWith('http')) return t;
      }
    }
    return null;
  }

  String? _lookupJourneyName(Map<String, String> lookup, String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) return null;
    if (lookup.containsKey(id)) return lookup[id];

    final normalized = LandmarkMemoryDataSource.normalizeCatalogJourneyId(
      catalogJourneyId: id,
    );
    if (normalized.isNotEmpty && lookup.containsKey(normalized)) {
      return lookup[normalized];
    }

    final match = RegExp(
      r'^journey_?(\d+)$',
      caseSensitive: false,
    ).firstMatch(id);
    if (match != null) {
      final num = match.group(1)!;
      for (final variant in ['journey_$num', 'journey$num']) {
        if (lookup.containsKey(variant)) return lookup[variant];
      }
    }
    return null;
  }

  /// One profile journey per catalog journey (`journey_1` == `journey1`).
  String _canonicalJourneyId(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) return '';
    final normalized = LandmarkMemoryDataSource.normalizeCatalogJourneyId(
      catalogJourneyId: id,
    );
    if (normalized.isNotEmpty) return normalized;
    return id.replaceAll('_', '');
  }

  String _prettifyJourneyId(String id) {
    final trimmed = id.trim();
    final match = RegExp(
      r'^journey_?(\d+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null) {
      final l10n = AppLocalizations.of(context);
      if (l10n != null) return l10n.profileJourneyNumber(match.group(1)!);
      return 'Journey ${match.group(1)}';
    }
    return trimmed;
  }

  String _resolveDisplayJourneyName(
    Map<String, String> lookup, {
    String? journeyId,
    String? storedName,
  }) {
    final id = journeyId?.trim() ?? '';
    final stored = storedName?.trim();

    if (id.isNotEmpty) {
      final fromCatalog = _lookupJourneyName(lookup, id);
      if (fromCatalog != null && fromCatalog.isNotEmpty) return fromCatalog;
    }

    if (stored != null && stored.isNotEmpty && (id.isEmpty || stored != id)) {
      return stored;
    }

    if (stored != null && stored.isNotEmpty) return stored;
    if (id.isNotEmpty) return _prettifyJourneyId(id);
    return AppLocalizations.of(context)?.profileJourneyFallback ?? 'Journey';
  }

  void _openUserPhoto(Map<String, dynamic> photo) {
    final url = photo['url']?.toString().trim() ?? '';
    if (url.isEmpty) return;
    final landmark = photo['landmarkTitle']?.toString().trim();
    final journey = photo['journeyName']?.toString().trim();
    UserMediaPreviewSheet.show(
      context,
      imageUrl: url,
      title: (landmark != null && landmark.isNotEmpty)
          ? landmark
          : (journey != null && journey.isNotEmpty ? journey : null),
      subtitle:
          (landmark != null &&
              landmark.isNotEmpty &&
              journey != null &&
              journey.isNotEmpty)
          ? journey
          : null,
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _queryDocs(
    Future<QuerySnapshot<Map<String, dynamic>>> future,
    String label,
  ) async {
    try {
      return (await future).docs;
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] $label: $e');
      return [];
    }
  }

  Future<List<LandmarkMemory>> _loadMemories(String uid) async {
    try {
      return await _memoryDs.fetchAllMemoriesForUser(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] memories: $e');
      return const [];
    }
  }

  Future<List<Journey>> _loadJourneyCatalog() async {
    try {
      return await _journeyDs.getAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] journeys catalog: $e');
      return const [];
    }
  }

  Future<Map<String, String>> _resolveJourneyNames(Iterable<String> ids) async {
    final out = <String, String>{};
    final toFetch = <String>[];
    for (final journeyId
        in ids.map((e) => e.trim()).where((e) => e.isNotEmpty)) {
      final cached = JourneyDataSource.findInCatalogCache(journeyId);
      if (cached != null) {
        out[journeyId] = cached.name;
      } else {
        toFetch.add(journeyId);
      }
    }
    if (toFetch.isEmpty) return out;
    await Future.wait(
      toFetch.map((journeyId) async {
        try {
          final jd = await _firestore
              .collection('journeys')
              .doc(journeyId)
              .get();
          if (jd.exists) {
            final n = (jd.data()?['name'] as String?)?.trim();
            if (n != null && n.isNotEmpty) out[journeyId] = n;
          }
        } catch (_) {}
      }),
    );
    return out;
  }

  void _sortPhotoEntries(List<Map<String, dynamic>> photoEntries) {
    photoEntries.sort((a, b) {
      final ta = a['createdAt'] as DateTime?;
      final tb = b['createdAt'] as DateTime?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;
    final uid = user.uid;
    final generalFeedbackLabel = AppLocalizations.of(
      context,
    )!.profileFeedbackGeneral;

    // Perf: keep showing cached sections while refreshing in background.
    if (mounted && !_hadCachedSnapshotOnOpen) {
      setState(() => _isProfileDataLoading = true);
    }

    try {
      final userDocFuture = _firestore.collection('users').doc(uid).get();
      final photosFuture = _queryDocs(
        _firestore.collection('photos').where('userId', isEqualTo: uid).get(),
        'photos',
      );
      final completionFuture = _queryDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(
              JourneyCompletionDataSource.userCompletionHistorySubcollection,
            )
            .get(),
        'journeyCompletionHistory',
      );
      final legacyFuture = _queryDocs(
        _firestore
            .collection('user_journeys')
            .where('userId', isEqualTo: uid)
            .get(),
        'user_journeys',
      );
      final completionsFuture = _queryDocs(
        _firestore
            .collection(_journeyCompletionsCollection)
            .where('userId', isEqualTo: uid)
            .get(),
        'journeyCompletions',
      );
      final journeyHistoryFuture = _queryDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(LandmarkMemoryDataSource.journeyHistorySubcollection)
            .get(),
        'journeyHistory',
      );
      final activeJourneysFuture = _queryDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(JourneyProgressDataSource.activeJourneysSubcollection)
            .get(),
        'activeJourneys',
      );
      final feedbackRootFuture = _queryDocs(
        _firestore.collection('feedback').where('userId', isEqualTo: uid).get(),
        'feedback',
      );
      final feedbackProfileFuture = _queryDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(FeedbackDataSource.userFeedbackSubcollection)
            .get(),
        'journeyFeedback',
      );
      final memoriesFuture = _loadMemories(uid);
      final catalogFuture = _loadJourneyCatalog();

      final userDoc = await userDocFuture;
      if (!mounted) return;

      final authEmail = user.email?.trim() ?? '';
      final fsEmail = (userDoc.data()?['email'] as String?)?.trim() ?? '';
      if (authEmail.isNotEmpty &&
          authEmail.toLowerCase() != fsEmail.toLowerCase()) {
        unawaited(_syncProfileEmail(uid, authEmail));
      }
      _applyUserDocument(userDoc, user);

      final batch = await Future.wait([
        photosFuture,
        completionFuture,
        legacyFuture,
        completionsFuture,
        journeyHistoryFuture,
        activeJourneysFuture,
        feedbackRootFuture,
        feedbackProfileFuture,
        memoriesFuture,
        catalogFuture,
      ]);
      if (!mounted) return;

      final photoDocs =
          batch[0] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final completionHistDocs =
          batch[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final legacyJourneyDocs =
          batch[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final completionsDocs =
          batch[3] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final journeyHistoryDocs =
          batch[4] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final activeJourneyDocs =
          batch[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final feedbackRootDocs =
          batch[6] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final feedbackProfileDocs =
          batch[7] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
      final landmarkMemories = batch[8] as List<LandmarkMemory>;
      final catalogJourneys = batch[9] as List<Journey>;

      if (kDebugMode) {
        debugPrint(
          '[Profile] loaded counts: history=${completionHistDocs.length} '
          'legacy=${legacyJourneyDocs.length} completions=${completionsDocs.length} '
          'active=${activeJourneyDocs.length} journeyHistory=${journeyHistoryDocs.length} '
          'memories=${landmarkMemories.length} '
          'feedbackRoot=${feedbackRootDocs.length} feedbackProfile=${feedbackProfileDocs.length}',
        );
      }

      final journeyRows = <Map<String, dynamic>>[];
      final epoch0 = DateTime.fromMillisecondsSinceEpoch(0);

      bool hasCanonicalJourney(String journeyId) {
        final c = _canonicalJourneyId(journeyId);
        if (c.isEmpty) return false;
        return journeyRows.any(
          (r) => _canonicalJourneyId(r['journeyId'] as String? ?? '') == c,
        );
      }

      void addJourneyRow({
        required String journeyId,
        required String name,
        required DateTime sort,
        required String rowId,
        String? userJourneyId,
        String? historyDocId,
        String? completionDocId,
      }) {
        final jid = journeyId.trim();
        final canonical = _canonicalJourneyId(jid);
        if (jid.isEmpty && canonical.isEmpty) return;
        final uj = userJourneyId?.trim();
        journeyRows.add({
          'journeyId': jid.isNotEmpty ? jid : canonical,
          'name': name,
          'sort': sort,
          'dateLabel': sort.millisecondsSinceEpoch > 0
              ? _formatExactDate(sort)
              : '',
          'rowId': rowId,
          if (uj != null && uj.isNotEmpty) 'userJourneyId': uj,
          if (historyDocId != null && historyDocId.isNotEmpty)
            'historyDocId': historyDocId,
          if (completionDocId != null && completionDocId.isNotEmpty)
            'completionDocId': completionDocId,
        });
      }

      // One card per completion (not merged into a single journey card).
      for (final doc in completionHistDocs) {
        final data = doc.data();
        final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
        final sort = _coerceToDateTime(data['completedAt']) ?? epoch0;
        final fromField = (data['userJourneyId'] as String?)?.trim();
        final docId = doc.id.trim();
        String? playthroughId;
        if (fromField != null &&
            fromField.isNotEmpty &&
            !LandmarkMemoryDataSource.isCatalogJourneyDocId(
              fromField,
              catalogJourneyId: journeyId,
            )) {
          playthroughId = fromField;
        } else if (!LandmarkMemoryDataSource.isCatalogJourneyDocId(
          docId,
          catalogJourneyId: journeyId,
        )) {
          playthroughId = docId;
        }
        addJourneyRow(
          journeyId: journeyId,
          name: journeyId,
          sort: sort,
          rowId: 'completion_${doc.id}',
          userJourneyId: playthroughId,
          completionDocId: doc.id,
        );
      }

      for (final doc in legacyJourneyDocs) {
        final data = doc.data();
        final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
        final name = (data['journeyName'] as String?)?.trim() ?? '';
        final sort =
            _coerceToDateTime(data['date']) ??
            _coerceToDateTime(data['completedAt']) ??
            epoch0;
        addJourneyRow(
          journeyId: journeyId,
          name: name.isNotEmpty
              ? name
              : (journeyId.isNotEmpty ? journeyId : 'Journey'),
          sort: sort,
          rowId: 'legacy_${doc.id}',
        );
      }

      if (completionHistDocs.isEmpty) {
        for (final doc in completionsDocs) {
          final data = doc.data();
          final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
          final sort = _coerceToDateTime(data['completedAt']) ?? epoch0;
          addJourneyRow(
            journeyId: journeyId,
            name: journeyId,
            sort: sort,
            rowId: 'completion_root_${doc.id}',
          );
        }
      }

      for (final doc in activeJourneyDocs) {
        final data = doc.data();
        final journeyId =
            (data['journeyId'] as String?)?.trim().isNotEmpty == true
            ? (data['journeyId'] as String).trim()
            : doc.id;
        final title = (data['journeyTitle'] as String?)?.trim();
        final sort =
            _coerceToDateTime(data['lastUpdatedAt']) ??
            _coerceToDateTime(data['updatedAt']) ??
            DateTime.now();
        final playthroughId = (data['userJourneyId'] as String?)?.trim();
        addJourneyRow(
          journeyId: journeyId,
          name: (title != null && title.isNotEmpty) ? title : journeyId,
          sort: sort,
          rowId: 'active_${doc.id}',
          userJourneyId:
              playthroughId != null &&
                  playthroughId.isNotEmpty &&
                  !LandmarkMemoryDataSource.isCatalogJourneyDocId(
                    playthroughId,
                    catalogJourneyId: journeyId,
                  )
              ? playthroughId
              : null,
        );
      }

      for (final doc in journeyHistoryDocs) {
        final data = doc.data();
        final journeyId =
            ((data['journeyId'] as String?)?.trim().isNotEmpty ?? false)
            ? (data['journeyId'] as String).trim()
            : doc.id;
        if (hasCanonicalJourney(journeyId)) continue;
        if (LandmarkMemoryDataSource.isCatalogJourneyDocId(
          doc.id,
          catalogJourneyId: journeyId,
        )) {
          continue;
        }
        final title = (data['journeyTitle'] as String?)?.trim();
        final sort = _coerceToDateTime(data['lastUpdatedAt']) ?? epoch0;
        final parentInstance =
            (data['userJourneyId'] as String?)?.trim() ??
            (data['journeyHistoryId'] as String?)?.trim();
        addJourneyRow(
          journeyId: journeyId,
          name: (title != null && title.isNotEmpty) ? title : journeyId,
          sort: sort,
          rowId: 'history_${doc.id}',
          userJourneyId: parentInstance?.isNotEmpty == true
              ? parentInstance
              : doc.id,
          historyDocId: doc.id,
        );
      }

      for (final mem in landmarkMemories) {
        final journeyId = mem.journeyId.trim();
        if (journeyId.isEmpty || hasCanonicalJourney(journeyId)) continue;
        final sort = mem.createdAt ?? epoch0;
        addJourneyRow(
          journeyId: journeyId,
          name: mem.journeyTitle.trim().isNotEmpty
              ? mem.journeyTitle
              : journeyId,
          sort: sort,
          rowId: 'memory_${journeyId}_${sort.millisecondsSinceEpoch}',
        );
      }

      journeyRows.sort(
        (a, b) => (b['sort'] as DateTime).compareTo(a['sort'] as DateTime),
      );

      final nameSeed = <String, String>{};
      for (final doc in journeyHistoryDocs) {
        final data = doc.data();
        final jid = ((data['journeyId'] as String?)?.trim().isNotEmpty ?? false)
            ? (data['journeyId'] as String).trim()
            : doc.id;
        final title = (data['journeyTitle'] as String?)?.trim();
        if (jid.isNotEmpty && title != null && title.isNotEmpty) {
          nameSeed[jid] = title;
        }
      }
      for (final row in journeyRows) {
        final jid = row['journeyId'] as String? ?? '';
        final rowName = (row['name'] as String?)?.trim() ?? '';
        if (jid.isNotEmpty &&
            rowName.isNotEmpty &&
            rowName != jid &&
            rowName != 'Journey') {
          nameSeed[jid] = rowName;
        }
      }

      final nameLookup = _journeyNameLookupFromCatalog(
        seed: nameSeed,
        catalog: catalogJourneys,
        requiredIds: journeyRows
            .map((r) => r['journeyId'] as String)
            .where((s) => s.isNotEmpty),
      );
      final missingIds = journeyRows
          .map((r) => r['journeyId'] as String)
          .where(
            (id) => id.isNotEmpty && _lookupJourneyName(nameLookup, id) == null,
          );
      final resolved = await _resolveJourneyNames(missingIds);
      nameLookup.addAll(resolved);
      _journeyNameLookup = nameLookup;

      for (final row in journeyRows) {
        final jid = row['journeyId'] as String? ?? '';
        row['name'] = _resolveDisplayJourneyName(
          nameLookup,
          journeyId: jid,
          storedName: row['name'] as String?,
        );
        final sort = row['sort'] as DateTime;
        if (sort.millisecondsSinceEpoch > 0) {
          row['dateLabel'] = _formatExactDate(sort);
        }
      }

      userJourneys = journeyRows.map((r) {
        final rowId = r['rowId'] as String? ?? '';
        String? historyDocId;
        String? completionDocId;
        if (rowId.startsWith('history_')) {
          historyDocId = rowId.substring('history_'.length);
        } else if (rowId.startsWith('completion_root_')) {
          completionDocId = rowId.substring('completion_root_'.length);
        } else if (rowId.startsWith('completion_')) {
          completionDocId = rowId.substring('completion_'.length);
        } else if (rowId.startsWith('active_')) {
          historyDocId = rowId.substring('active_'.length);
        }
        final userJourneyId = JourneyHistoryScope.resolveInstanceId(r);
        final sort = r['sort'];
        final rawCompletion = r['completionDocId']?.toString().trim();
        final effectiveCompletion =
            (rawCompletion != null && rawCompletion.isNotEmpty)
            ? rawCompletion
            : completionDocId;
        return {
          'name': r['name'],
          'date': r['dateLabel'],
          'journeyId': r['journeyId'],
          'sort': sort,
          'rowId': rowId,
          if (sort is DateTime) 'completedAt': sort,
          if (userJourneyId != null && userJourneyId.isNotEmpty)
            'userJourneyId': userJourneyId,
          if (historyDocId != null && historyDocId.isNotEmpty)
            'historyDocId': historyDocId,
          if (effectiveCompletion != null && effectiveCompletion.isNotEmpty)
            'completionDocId': effectiveCompletion,
        };
      }).toList();
      journeysCount = userJourneys.length;

      final feedbackById = <String, Map<String, dynamic>>{};
      for (final doc in feedbackRootDocs) {
        feedbackById[doc.id] = doc.data();
      }
      for (final doc in feedbackProfileDocs) {
        feedbackById.putIfAbsent(doc.id, () => doc.data());
      }

      int feedbackSortKey(Map<String, dynamic> data) {
        final ts = data['createdAt'];
        if (ts is Timestamp) return ts.millisecondsSinceEpoch;
        return 0;
      }

      final mergedFeedback = feedbackById.entries.toList()
        ..sort((a, b) {
          final ka = feedbackSortKey(a.value);
          final kb = feedbackSortKey(b.value);
          if (ka != 0 || kb != 0) return kb.compareTo(ka);
          return b.key.compareTo(a.key);
        });

      userFeedbacks = mergedFeedback.map((e) {
        final data = e.value;
        final journeyId = data['journeyId'];
        final storedTitle =
            (data['journeyTitle'] as String?)?.trim() ??
            (data['journeyName'] as String?)?.trim();
        final journeyName = journeyId == null || journeyId == 'all'
            ? generalFeedbackLabel
            : _resolveDisplayJourneyName(
                nameLookup,
                journeyId: journeyId.toString(),
                storedName: storedTitle,
              );
        final rawPhotos = data['photos'];
        final urls = rawPhotos is List
            ? rawPhotos
                  .whereType<String>()
                  .where((u) => u.trim().startsWith('http'))
                  .toList()
            : <String>[];
        final rating =
            (data['overallRating'] as num?)?.toInt() ??
            (data['rating'] as num?)?.toInt() ??
            0;
        final comment =
            (data['overallComment'] as String?)?.trim().isNotEmpty == true
            ? data['overallComment'] as String
            : (data['comment'] as String?) ?? '';
        final createdAt = _coerceToDateTime(data['createdAt']);
        return {
          'rating': rating.clamp(0, 5),
          'comment': comment,
          'date': createdAt,
          'dateLabel': _formatExactDate(createdAt),
          'journeyName': journeyName,
          'name': journeyName,
          'journeyId': journeyId?.toString(),
          'photos': urls,
        };
      }).toList();

      final photoEntries = <Map<String, dynamic>>[];
      for (final doc in photoDocs) {
        final data = doc.data();
        final url = _photoUrlFromDoc(data);
        if (url == null) continue;
        photoEntries.add({
          'url': url,
          'journeyName':
              data['journeyName']?.toString() ?? data['journey']?.toString(),
          'createdAt': _coerceToDateTime(
            data['createdAt'] ?? data['takenAt'] ?? data['timestamp'],
          ),
          'source': 'photos',
        });
      }
      for (final fb in userFeedbacks) {
        for (final u in fb['photos'] as List<dynamic>) {
          if (u is! String || !u.trim().startsWith('http')) continue;
          photoEntries.add({
            'url': u.trim(),
            'journeyName': fb['journeyName'],
            'createdAt': fb['date'] as DateTime?,
            'source': 'feedback',
          });
        }
      }
      for (final mem in landmarkMemories) {
        if (mem.isVideo) continue;
        photoEntries.add({
          'url': mem.mediaUrl,
          'journeyName': mem.journeyTitle,
          'createdAt': mem.createdAt,
          'source': 'journey',
          'landmarkTitle': mem.landmarkTitle,
        });
      }
      _sortPhotoEntries(photoEntries);
      userPhotos = photoEntries;
      photosCount = userPhotos.length;
      _saveSnapshot(uid);
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProfileDataLoading = false;
          _hadCachedSnapshotOnOpen = false;
        });
      }
    }
  }

  Future<void> _syncProfileEmail(String uid, String authEmail) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': authEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (kDebugMode) {
        debugPrint('[Profile] synced Firestore email from Auth uid=$uid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] email sync skipped: $e');
    }
  }

  Map<String, String> _journeyNameLookupFromCatalog({
    required Map<String, String> seed,
    required List<Journey> catalog,
    required Iterable<String> requiredIds,
  }) {
    final lookup = Map<String, String>.from(seed);

    void registerAlias(String key, String name) {
      final k = key.trim();
      final n = name.trim();
      if (k.isEmpty || n.isEmpty) return;
      lookup.putIfAbsent(k, () => n);

      final normalized = LandmarkMemoryDataSource.normalizeCatalogJourneyId(
        catalogJourneyId: k,
      );
      if (normalized.isNotEmpty) {
        lookup.putIfAbsent(normalized, () => n);
      }

      final match = RegExp(
        r'^journey_?(\d+)$',
        caseSensitive: false,
      ).firstMatch(k);
      if (match != null) {
        final num = match.group(1)!;
        lookup.putIfAbsent('journey_$num', () => n);
        lookup.putIfAbsent('journey$num', () => n);
      }
    }

    for (final journey in catalog) {
      final title = journey.name.trim();
      if (title.isEmpty || title == 'Journey') continue;
      registerAlias(journey.journeyId, title);
      final landmarksId = journey.landmarksJourneyId?.trim();
      if (landmarksId != null && landmarksId.isNotEmpty) {
        registerAlias(landmarksId, title);
      }
    }

    for (final id in requiredIds) {
      _lookupJourneyName(lookup, id);
    }
    return lookup;
  }

  Future<void> _logout() async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (c) => LoginScreen(
          hideBackButton: true,
          authBottomNav: AppBottomNav(
            selectedIndex: 2,
            onHomeTap: () => Navigator.of(c).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const LandingPage()),
              (_) => false,
            ),
            onActiveJourneysTap: () => Navigator.of(c).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => const JourneyListScreen(),
              ),
              (_) => false,
            ),
            onProfileTap: () {},
          ),
        ),
      ),
      (_) => false,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 70,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: AppLocalizations.of(context)!.profileEditProfile,
                icon: Icon(Icons.edit_outlined, color: AppColors.brown),
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  );
                  if (changed == true && mounted) {
                    _hydrateFromAuthSync();
                    await _loadUserData();
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.help_outline, color: AppColors.brown),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FaqsPage()),
                  );
                },
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout, color: AppColors.brown),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {required VoidCallback onShowAll}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.brown,
            ),
          ),
        ),
        TextButton(
          onPressed: onShowAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            AppLocalizations.of(context)!.profileShowAll,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _openSectionList(ProfileSectionKind kind, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSectionListScreen(
          title: title,
          kind: kind,
          journeys: userJourneys,
          feedbacks: userFeedbacks,
          photos: userPhotos,
          journeyTitleFor: _cardJourneyTitle,
          formatExactDate: _formatExactDate,
          onOpenPhoto: _openUserPhoto,
        ),
      ),
    );
  }

  String _cardJourneyTitle(Map<String, dynamic> item) {
    final id = item['journeyId']?.toString().trim();
    final stored = (item['name'] ?? item['journeyName'])?.toString().trim();
    if (_journeyNameLookup.isNotEmpty) {
      return _resolveDisplayJourneyName(
        _journeyNameLookup,
        journeyId: id,
        storedName: stored,
      );
    }
    if (stored != null && stored.isNotEmpty && (id == null || stored != id)) {
      return stored;
    }
    if (id != null && id.isNotEmpty) return _prettifyJourneyId(id);
    return 'Journey';
  }

  Widget _buildJourneyCard(
    Map<String, dynamic> journey, {
    bool fullWidth = false,
  }) {
    final title = _cardJourneyTitle(journey);
    final dateStr = journey['date']?.toString() ?? '';
    final journeyId = journey['journeyId']?.toString() ?? '';
    return Material(
      color: AppColors.beige.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: journeyId.isEmpty
            ? null
            : () {
                final scope = JourneyHistoryScope.fromProfileRow(journey);
                final completedAt = journey['completedAt'] is DateTime
                    ? journey['completedAt'] as DateTime
                    : (journey['sort'] is DateTime
                          ? journey['sort'] as DateTime
                          : scope.completedAt);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => JourneyHistoryMemoriesScreen(
                      journeyId: scope.catalogJourneyId,
                      journeyName: title,
                      historyDocId:
                          journey['historyDocId']?.toString() ??
                          scope.historyDocId,
                      completionDocId:
                          journey['completionDocId']?.toString() ??
                          scope.completionDocId,
                      userJourneyId:
                          journey['userJourneyId']?.toString() ??
                          scope.userJourneyId,
                      completedAt: completedAt,
                    ),
                  ),
                );
              },
        child: Container(
          width: fullWidth ? double.infinity : 200,
          height: _profileSectionHeight,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brown.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.route,
                    size: 18,
                    color: AppColors.brown.withOpacity(0.85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                ],
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: AppColors.brown.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brown.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLoadingPlaceholder() {
    return Container(
      height: _profileSectionHeight,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.brown.withOpacity(0.45),
        ),
      ),
    );
  }

  Widget _buildJourneysSection() {
    if (_isProfileDataLoading) {
      return _sectionLoadingPlaceholder();
    }
    if (userJourneys.isEmpty) {
      return _emptyBox(AppLocalizations.of(context)!.profileNoJourneysYet);
    }
    final visible = userJourneys.take(_profilePreviewLimit).toList();
    return SizedBox(
      height: _profileSectionHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => _buildJourneyCard(visible[index]),
      ),
    );
  }

  Widget _buildPhotosSection() {
    if (_isProfileDataLoading) {
      return _sectionLoadingPlaceholder();
    }
    if (userPhotos.isEmpty) {
      return _emptyBox(AppLocalizations.of(context)!.profileNoPhotosYet);
    }
    final thumbSize = _profileSectionHeight - 24;
    final visible = userPhotos.take(_profilePreviewLimit).toList();
    return SizedBox(
      height: _profileSectionHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) =>
            _photoThumbnail(visible[index], size: thumbSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayJoined = joinedDate == 'Unknown'
        ? l10n.profileJoinedUnknown
        : joinedDate;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.beige.withValues(
                            alpha: 0.88,
                          ),
                          backgroundImage:
                              profileImageUrl != null &&
                                  profileImageUrl!.isNotEmpty
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          onBackgroundImageError: profileImageUrl != null
                              ? (Object o, StackTrace? st) {
                                  if (kDebugMode) {
                                    debugPrint(
                                      '[Profile] avatar load error: $o',
                                    );
                                  }
                                  if (mounted) {
                                    setState(() => profileImageUrl = null);
                                  }
                                }
                              : null,
                          child:
                              profileImageUrl == null ||
                                  profileImageUrl!.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.brown.withOpacity(0.7),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.profileHello(userName),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.brown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.profileJoined(displayJoined),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.brown.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _statBox(
                              _isProfileDataLoading ? '…' : '$journeysCount',
                              l10n.profileStatJourneys,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _statBox(
                              _isProfileDataLoading ? '…' : '$photosCount',
                              l10n.profileStatPhotos,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      _buildSectionHeader(
                        l10n.profileMyJourneys,
                        onShowAll: () => _openSectionList(
                          ProfileSectionKind.journeys,
                          l10n.profileMyJourneys,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildJourneysSection(),
                      const SizedBox(height: 30),
                      _buildSectionHeader(
                        l10n.profileMyPhotos,
                        onShowAll: () => _openSectionList(
                          ProfileSectionKind.photos,
                          l10n.profileMyPhotos,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildPhotosSection(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onHomeTap: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        onActiveJourneysTap: () {
          final nav = Navigator.of(context);
          nav.popUntil((route) => route.isFirst);
          nav.push(
            MaterialPageRoute<void>(builder: (_) => const JourneyListScreen()),
          );
        },
        onProfileTap: () {},
      ),
    );
  }

  Widget _photoThumbnail(Map<String, dynamic> photo, {double size = 96}) {
    final url = photo['url']?.toString().trim() ?? '';
    final landmark = photo['landmarkTitle']?.toString().trim();
    final journey = photo['journeyName']?.toString().trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppColors.brown.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () => _openUserPhoto(photo),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppNetworkImage(
                  url: url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  memCacheWidth: (size * 2).round(),
                  error: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.brown.withOpacity(0.45),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: UserMediaCardActionsButton(
                    imageUrl: url,
                    title: (landmark != null && landmark.isNotEmpty)
                        ? landmark
                        : journey,
                    subtitle: journey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.brown,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      height: _profileSectionHeight,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.brown),
      ),
    );
  }
}
