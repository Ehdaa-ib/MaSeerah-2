import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/firebase/feedback_data_source.dart';
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../faq/faqs_page.dart';
import '../journey/journey_list_screen.dart';
import '../auth/login_screen.dart';
import 'landing_page.dart';
import 'edit_profile_screen.dart';

/// Matches [JourneyCompletionDataSource] root collection (private there).
const String _journeyCompletionsCollection = 'journeyCompletions';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userName = "";
  String joinedDate = "";
  String? profileImageUrl;
  int journeysCount = 0;
  int photosCount = 0;
  List<Map<String, dynamic>> userJourneys = [];
  List<Map<String, dynamic>> userFeedbacks = [];
  /// Each entry: `url` (String), optional `journeyName`, `createdAt` (DateTime?), `source` (String).
  List<Map<String, dynamic>> userPhotos = [];

  @override
  void initState() {
    super.initState();
    _hydrateFromAuthSync();
    _loadUserData();
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
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  /// Prefer Firestore `createdAt` (user doc); fall back to legacy `joinedDate` / snake_case aliases.
  DateTime? _readJoinDateFromUserDoc(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v = data['createdAt'] ??
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

  Future<Map<String, String>> _resolveJourneyNames(Iterable<String> ids) async {
    final out = <String, String>{};
    final unique = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    await Future.wait(unique.map((journeyId) async {
      try {
        final jd = await _firestore.collection('journeys').doc(journeyId).get();
        if (jd.exists) {
          final n = (jd.data()?['name'] as String?)?.trim();
          if (n != null && n.isNotEmpty) out[journeyId] = n;
        }
      } catch (_) {}
    }));
    return out;
  }

  void _openPhotoViewer(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: AppColors.beige),
                );
              },
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(24),
                child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeDocs(
      Future<QuerySnapshot<Map<String, dynamic>>> future,
      String label,
    ) async {
      try {
        return (await future).docs;
      } catch (e) {
        if (kDebugMode) debugPrint('[Profile] $label failed (other data still loads): $e');
        return [];
      }
    }

    try {
      final userDocFuture = _firestore.collection('users').doc(uid).get();
      final photosFuture = safeDocs(
        _firestore.collection('photos').where('userId', isEqualTo: uid).get(),
        'photos',
      );
      final completionFuture = safeDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(JourneyCompletionDataSource.userCompletionHistorySubcollection)
            .get(),
        'journeyCompletionHistory',
      );
      final userJourneysLegacyFuture = safeDocs(
        _firestore.collection('user_journeys').where('userId', isEqualTo: uid).get(),
        'user_journeys',
      );
      final journeyCompletionsFuture = safeDocs(
        _firestore.collection(_journeyCompletionsCollection).where('userId', isEqualTo: uid).get(),
        'journeyCompletions',
      );
      final feedbackRootFuture = safeDocs(
        _firestore.collection('feedback').where('userId', isEqualTo: uid).get(),
        'feedback',
      );
      final feedbackProfileFuture = safeDocs(
        _firestore
            .collection('users')
            .doc(uid)
            .collection(FeedbackDataSource.userFeedbackSubcollection)
            .get(),
        'journeyFeedback',
      );

      final userDoc = await userDocFuture;
      if (!mounted) return;

      var docForApply = userDoc;
      final authEmail = user.email?.trim() ?? '';
      final fsEmail = (userDoc.data()?['email'] as String?)?.trim() ?? '';
      var didSync = false;
      if (authEmail.isNotEmpty && authEmail.toLowerCase() != fsEmail.toLowerCase()) {
        try {
          await _firestore.collection('users').doc(uid).set(
            {
              'email': authEmail,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          didSync = true;
          if (kDebugMode) {
            debugPrint('[Profile] synced Firestore email from Auth uid=$uid');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[Profile] email sync skipped: $e');
        }
      }
      if (didSync) {
        docForApply = await _firestore.collection('users').doc(uid).get();
      }
      if (!mounted) return;
      setState(() => _applyUserDocument(docForApply, user));

      final batch = await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
        photosFuture,
        completionFuture,
        userJourneysLegacyFuture,
        journeyCompletionsFuture,
      ]);
      if (!mounted) return;

      final photoDocs = batch[0];
      final completionHistDocs = batch[1];
      final legacyJourneyDocs = batch[2];
      final completionsDocs = batch[3];

      final journeyRows = <Map<String, dynamic>>[];

      for (final doc in completionHistDocs) {
        final data = doc.data();
        final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
        final ts = data['completedAt'];
        final sort = _coerceToDateTime(ts);
        journeyRows.add({
          'journeyId': journeyId,
          'name': journeyId,
          'dateLabel': sort != null ? _formatDate(sort) : '',
          'sort': sort ?? DateTime.fromMillisecondsSinceEpoch(0),
          'source': 'history',
        });
      }

      for (final doc in legacyJourneyDocs) {
        final data = doc.data();
        final name = (data['journeyName'] as String?)?.trim() ?? '';
        final sort = _coerceToDateTime(data['date']) ?? _coerceToDateTime(data['completedAt']);
        final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
        journeyRows.add({
          'journeyId': journeyId,
          'name': name.isNotEmpty ? name : (journeyId.isNotEmpty ? journeyId : 'Journey'),
          'dateLabel': sort != null ? _formatDate(sort) : (data['date']?.toString() ?? ''),
          'sort': sort ?? DateTime.fromMillisecondsSinceEpoch(0),
          'source': 'legacy',
        });
      }

      if (journeyRows.isEmpty && completionsDocs.isNotEmpty) {
        for (final doc in completionsDocs) {
          final data = doc.data();
          final journeyId = (data['journeyId'] as String?)?.trim() ?? '';
          final ts = data['completedAt'];
          final sort = _coerceToDateTime(ts);
          journeyRows.add({
            'journeyId': journeyId,
            'name': journeyId,
            'dateLabel': sort != null ? _formatDate(sort) : '',
            'sort': sort ?? DateTime.fromMillisecondsSinceEpoch(0),
            'source': 'completion',
          });
        }
      }

      journeyRows.sort((a, b) => (b['sort'] as DateTime).compareTo(a['sort'] as DateTime));

      final idsForNames = journeyRows.map((r) => r['journeyId'] as String).where((s) => s.isNotEmpty);
      final nameById = await _resolveJourneyNames(idsForNames);
      for (final row in journeyRows) {
        final jid = row['journeyId'] as String? ?? '';
        if (jid.isNotEmpty && nameById.containsKey(jid)) {
          row['name'] = nameById[jid]!;
        } else if ((row['name'] as String).isEmpty || row['name'] == jid) {
          if (jid.isNotEmpty) row['name'] = jid;
        }
      }

      userJourneys = journeyRows
          .map((r) => {
                'name': r['name'],
                'date': r['dateLabel'],
              })
          .toList();
      journeysCount = userJourneys.length;

      final photoEntries = <Map<String, dynamic>>[];
      for (final doc in photoDocs) {
        final data = doc.data();
        final url = _photoUrlFromDoc(data);
        if (url == null) continue;
        photoEntries.add({
          'url': url,
          'journeyName': data['journeyName']?.toString() ?? data['journey']?.toString(),
          'createdAt': _coerceToDateTime(data['createdAt'] ?? data['takenAt'] ?? data['timestamp']),
          'source': 'photos',
        });
      }

      if (!mounted) return;
      setState(() {});

      final feedbackBatch = await Future.wait([
        feedbackRootFuture,
        feedbackProfileFuture,
      ]);
      if (!mounted) return;
      final feedbackRootDocs = feedbackBatch[0];
      final feedbackProfileDocs = feedbackBatch[1];
      if (kDebugMode) {
        debugPrint(
          '[Profile] loaded counts: history=${completionHistDocs.length} '
          'legacy=${legacyJourneyDocs.length} completions=${completionsDocs.length} '
          'feedbackRoot=${feedbackRootDocs.length} feedbackProfile=${feedbackProfileDocs.length}',
        );
      }
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

      final feedbackJourneyIds = mergedFeedback
          .map((e) => e.value['journeyId'])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != 'all');
      final fbNameById = await _resolveJourneyNames(feedbackJourneyIds);

      userFeedbacks = mergedFeedback.map((e) {
        final data = e.value;
        final journeyId = data['journeyId'];
        var journeyName = 'General';
        if (journeyId != null && journeyId != 'all') {
          final jid = journeyId.toString();
          journeyName = fbNameById[jid] ?? 'Unknown Journey';
        }
        final rawPhotos = data['photos'];
        final urls = rawPhotos is List
            ? rawPhotos.whereType<String>().where((u) => u.trim().startsWith('http')).toList()
            : <String>[];
        final rating = (data['overallRating'] as num?)?.toInt() ??
            (data['rating'] as num?)?.toInt() ??
            0;
        final comment = (data['overallComment'] as String?)?.trim().isNotEmpty == true
            ? data['overallComment'] as String
            : (data['comment'] as String?) ?? '';
        return {
          'rating': rating.clamp(0, 5),
          'comment': comment,
          'date': (data['createdAt'] as Timestamp?)?.toDate(),
          'journeyName': journeyName,
          'photos': urls,
        };
      }).toList();

      for (final fb in userFeedbacks) {
        final urls = fb['photos'] as List<dynamic>;
        for (final u in urls) {
          if (u is! String || !u.trim().startsWith('http')) continue;
          photoEntries.add({
            'url': u.trim(),
            'journeyName': fb['journeyName'],
            'createdAt': fb['date'] as DateTime?,
            'source': 'feedback',
          });
        }
      }

      photoEntries.sort((a, b) {
        final ta = a['createdAt'] as DateTime?;
        final tb = b['createdAt'] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      userPhotos = photoEntries;
      photosCount = userPhotos.length;
    } catch (e) {
      if (kDebugMode) debugPrint('[Profile] load error: $e');
    }

    if (mounted) setState(() {});
  }

  String _formatRelativeDate(DateTime? date) {
    if (date == null) return "";
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return "$diff days ago";
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
                tooltip: 'Edit profile',
                icon: Icon(Icons.edit_outlined, color: AppColors.brown),
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()),
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
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.language, color: AppColors.brown),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.logout, color: AppColors.brown),
                onPressed: _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                          backgroundColor: AppColors.beige.withValues(alpha: 0.88),
                          backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                              ? NetworkImage(profileImageUrl!)
                              : null,
                          onBackgroundImageError: profileImageUrl != null
                              ? (Object o, StackTrace? st) {
                                  if (kDebugMode) debugPrint('[Profile] avatar load error: $o');
                                  if (mounted) setState(() => profileImageUrl = null);
                                }
                              : null,
                          child: profileImageUrl == null || profileImageUrl!.isEmpty
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
                              "Hello, $userName!",
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
                                  "Joined $joinedDate",
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
                          Expanded(child: _statBox("$journeysCount", "JOURNEYS")),
                          const SizedBox(width: 16),
                          Expanded(child: _statBox("$photosCount", "PHOTOS")),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "My Journey",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brown,
                        ),
                      ),
                      const SizedBox(height: 12),
                      userJourneys.isEmpty
                          ? _emptyBox("No journeys yet")
                          : SizedBox(
                              height: 148,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: userJourneys.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final journey = userJourneys[index];
                                  final title = journey['name']?.toString() ?? 'Journey';
                                  final dateStr = journey['date']?.toString() ?? '';
                                  return Container(
                                    width: 200,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.beige.withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.brown.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.route,
                                                size: 18, color: AppColors.brown.withOpacity(0.85)),
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
                                              Icon(Icons.calendar_today,
                                                  size: 12, color: AppColors.brown.withOpacity(0.6)),
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
                                  );
                                },
                              ),
                            ),
                      const SizedBox(height: 30),
                      const Text(
                        "Feedback",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brown,
                        ),
                      ),
                      const SizedBox(height: 12),
                      userFeedbacks.isEmpty
                          ? _emptyBox("No feedback yet")
                          : SizedBox(
                              height: 248,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: userFeedbacks.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final fb = userFeedbacks[index];
                                  final stars = (fb['rating'] as num?)?.toInt() ?? 0;
                                  final photos =
                                      (fb['photos'] as List?)?.whereType<String>().toList() ?? [];
                                  return Container(
                                    width: 288,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.beige.withValues(alpha: 0.88),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.brown.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fb['journeyName']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.brown,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(
                                            5,
                                            (i) => Icon(
                                              i < stars ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: Text(
                                            fb['comment']?.toString() ?? '',
                                            maxLines: 4,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12, color: AppColors.brown),
                                          ),
                                        ),
                                        if (photos.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 64,
                                            child: ListView.separated(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: photos.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(width: 8),
                                              itemBuilder: (_, i) =>
                                                  _photoThumbnail(photos[i], size: 64),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          _formatRelativeDate(fb['date'] as DateTime?)
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.brown.withOpacity(0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                      const SizedBox(height: 30),
                      const Text(
                        "Your photos",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "From feedback uploads and saved journey photos.",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.brown.withOpacity(0.65),
                        ),
                      ),
                      const SizedBox(height: 12),
                      userPhotos.isEmpty
                          ? _emptyBox("No photos yet")
                          : SizedBox(
                              height: 104,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: userPhotos.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final url = userPhotos[index]['url'] as String;
                                  return _photoThumbnail(url, size: 96);
                                },
                              ),
                            ),
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

  Widget _photoThumbnail(String url, {double size = 96}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: AppColors.brown.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () => _openPhotoViewer(url),
          child: SizedBox(
            width: size,
            height: size,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                color: AppColors.brown.withOpacity(0.45),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brown.withOpacity(0.45),
                    ),
                  ),
                );
              },
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
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brown),
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.brown),
      ),
    );
  }
}