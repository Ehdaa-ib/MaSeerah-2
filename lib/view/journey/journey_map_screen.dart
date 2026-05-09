import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/error_messages.dart';
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/firebase/journey_landmark_data_source.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../challenge/challenge_renderer.dart';
import '../../model/journey.dart';
import '../../model/journey_landmark.dart';
import '../../service/landmark_maps_launch_service.dart';
import '../../util/place_image_asset.dart';
import '../auth/login_screen.dart';
import '../feedback/feedback_screen.dart';
import 'journey_purchase_screen.dart';
import 'widgets/journey_svg_map.dart';

/// High-contrast body text on beige (readability).
const Color _kReadableBody = Color(0xFF4A2F2A);

List<String> _splitDescriptionParagraphs(String text) {
  final t = text.trim();
  if (t.isEmpty) return const [];
  if (RegExp(r'\n\n+').hasMatch(t)) {
    return t.split(RegExp(r'\n\n+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  if (t.contains('\n')) {
    return t.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }
  final sentences =
      t.split(RegExp(r'(?<=[.!?])\s+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (sentences.length <= 2) return [t];
  final out = <String>[];
  final buf = StringBuffer();
  for (final s in sentences) {
    final prospective = buf.isEmpty ? s.length : buf.length + 1 + s.length;
    if (prospective > 280 && buf.isNotEmpty) {
      out.add(buf.toString().trim());
      buf.clear();
    }
    if (buf.isNotEmpty) buf.write(' ');
    buf.write(s);
  }
  if (buf.isNotEmpty) out.add(buf.toString().trim());
  return out;
}

/// Parses `**bold**` and `"quoted"` segments for landmark copy.
List<InlineSpan> _readableSpans(String segment) {
  const base = TextStyle(
    fontSize: 17,
    height: 1.62,
    color: _kReadableBody,
    fontWeight: FontWeight.w400,
  );
  const bold = TextStyle(
    fontSize: 17,
    height: 1.62,
    color: _kReadableBody,
    fontWeight: FontWeight.w700,
  );
  const quoted = TextStyle(
    fontSize: 17,
    height: 1.62,
    color: Color(0xFF6B4A3F),
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
  );

  final spans = <InlineSpan>[];
  void addBoldChunks(String chunk) {
    final parts = chunk.split(RegExp(r'\*\*'));
    for (var i = 0; i < parts.length; i++) {
      final style = i.isOdd ? bold : base;
      if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i], style: style));
    }
  }

  var rest = segment;
  while (rest.isNotEmpty) {
    final q1 = rest.indexOf('"');
    if (q1 < 0) {
      addBoldChunks(rest);
      break;
    }
    if (q1 > 0) addBoldChunks(rest.substring(0, q1));
    final q2 = rest.indexOf('"', q1 + 1);
    if (q2 < 0) {
      addBoldChunks(rest.substring(q1));
      break;
    }
    spans.add(TextSpan(text: rest.substring(q1, q2 + 1), style: quoted));
    rest = rest.substring(q2 + 1);
  }
  return spans;
}

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({
    super.key,
    /// Shown in the app bar until [catalogJourneyId] load completes (if any).
    this.journeyTitle = 'Journey',
    /// `journeyId` on `journey_landmarks` documents (Firestore).
    this.landmarksJourneyId = 'journey1',
    /// Document id in `journeys` (e.g. `journey_1`); used to load the real journey name.
    this.catalogJourneyId,
    /// Restored from [JourneyProgressDataSource] when continuing an in-progress journey.
    this.initialRegion,
    this.initialQubaChallengeCompleted = false,
    this.initialLastRegionChallengeCompleted = false,
  });

  final String journeyTitle;
  final String landmarksJourneyId;
  final String? catalogJourneyId;

  /// 1-based SVG / landmark order; clamped to the map when present.
  final int? initialRegion;
  final bool initialQubaChallengeCompleted;
  final bool initialLastRegionChallengeCompleted;

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  final _landmarkDs = JourneyLandmarkDataSource();
  final _progressDs = JourneyProgressDataSource();
  Timer? _saveProgressDebounce;
  Journey? _catalogJourney;

  /// Optional labels when Firestore has no doc yet for that [order]. DB name wins when present.
  /// Region 8 → Bustan Al-Mustazil (mirror in Firestore: `order: 8`, `name: "Bustan Al-Mustazil"`).
  static const Map<int, String> _knownRegionTitles = {
    8: 'Bustan Al-Mustazil',
  };

  /// SVG **region** → `journey_landmarks` **document id** when the doc id does not match `order`
  /// (e.g. region 8 uses doc `journey1landmark2`).
  static const Map<int, String> _regionLandmarkDocumentIds = {
    8: 'journey1landmark2',
  };

  /// Must match [JourneySvgMap.regionCount] for this map asset.
  static const int _mapRegionCount = 9;

  /// 1-based region index on the SVG; matches Firestore **[order]** (1 → Masjid Al-Nabawi, etc.).
  int currentRegion = 1;

  /// User completed the challenge flow from a stop whose title contains "quba" (Masjid Quba).
  bool _qubaChallengeCompleted = false;

  /// User completed the challenge for the final SVG region ([_mapRegionCount]).
  bool _lastRegionChallengeCompleted = false;

  /// Loaded landmarks; each [JourneyLandmark.order] links to the same-numbered region.
  List<JourneyLandmark> _landmarks = [];

  /// Landmarks loaded by explicit doc id for a region (takes priority over [order] matching).
  final Map<int, JourneyLandmark> _regionLandmarksByDocumentId = {};
  bool _landmarksLoading = true;

  /// When non-null, a full-screen beige sheet is open for this region (footer hidden).
  int? _regionSheetRegion;

  /// Empty "challenge" step after "Go to the challenge" (footer hidden until dismissed).
  bool _emptyChallengeOverlay = false;
  bool _noChallengeAutoAdvanceScheduled = false;

  /// Brief centered hint (wrong region / done region).
  String? _centerMessage;
  Timer? _centerMessageTimer;

  /// From `journeys/{catalogJourneyId}`; overrides [widget.journeyTitle] when set.
  String? _journeyNameFromDb;

  @override
  void initState() {
    super.initState();
    // Warm up asset-manifest image lookup so region sheets resolve photos immediately.
    Future<void>(() async {
      await prewarmPlaceImageResolver();
    });
    final r = widget.initialRegion;
    if (r != null && r >= 1 && r <= _mapRegionCount) {
      currentRegion = r.clamp(1, _mapRegionCount);
    }
    _qubaChallengeCompleted = widget.initialQubaChallengeCompleted;
    _lastRegionChallengeCompleted = widget.initialLastRegionChallengeCompleted;
    _loadLandmarks();
    _loadJourneyNameFromFirestore();
  }

  @override
  void dispose() {
    _saveProgressDebounce?.cancel();
    _centerMessageTimer?.cancel();
    super.dispose();
  }

  void _schedulePersistProgress() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final catalogId = _effectiveCatalogJourneyId();
    if (catalogId == null || catalogId.isEmpty) return;
    _saveProgressDebounce?.cancel();
    _saveProgressDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _flushPersistProgressNow();
    });
  }

  /// Writes progress immediately (used when leaving the map so Active Journeys / intro stay in sync).
  Future<void> _flushPersistProgressNow() async {
    _saveProgressDebounce?.cancel();
    _saveProgressDebounce = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final catalogId = _effectiveCatalogJourneyId();
    if (catalogId == null || catalogId.isEmpty) return;
    try {
      await _progressDs.upsert(
        userId: uid,
        journeyId: catalogId,
        journeyTitle: _appBarTitle(),
        landmarksJourneyId: widget.landmarksJourneyId.trim(),
        catalogJourneyId: catalogId,
        currentRegion: currentRegion.clamp(1, _mapRegionCount),
        qubaChallengeCompleted: _qubaChallengeCompleted,
        lastRegionChallengeCompleted: _lastRegionChallengeCompleted,
      );
    } catch (_) {}
  }

  Future<void> _leaveMapToJourneyIntro() async {
    // Persist in background; don't block navigation (avoids "button does nothing" feeling).
    // If writes are blocked by rules/network, we still navigate immediately.
    Future<void>(() async {
      try {
        await _flushPersistProgressNow().timeout(const Duration(seconds: 2));
      } catch (_) {}
    });
    if (!mounted) return;
    final catalogId = _effectiveCatalogJourneyId();
    if (catalogId != null && catalogId.isNotEmpty) {
      final optimistic = ActiveJourneyProgress(
        journeyId: catalogId,
        journeyTitle: _appBarTitle(),
        landmarksJourneyId: widget.landmarksJourneyId,
        catalogJourneyId: catalogId,
        currentRegion: currentRegion.clamp(1, _mapRegionCount),
        qubaChallengeCompleted: _qubaChallengeCompleted,
        lastRegionChallengeCompleted: _lastRegionChallengeCompleted,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => JourneyPurchaseScreen(
            journeyId: catalogId,
            initialJourney: _catalogJourney,
            initialSavedProgress: optimistic,
          ),
        ),
        (route) => route.isFirst,
      );
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showCenterMessage(String text) {
    _centerMessageTimer?.cancel();
    setState(() => _centerMessage = text);
    _centerMessageTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _centerMessage = null);
    });
  }

  bool get _footerVisible =>
      _regionSheetRegion == null && !_emptyChallengeOverlay;

  /// Bottom gap under the scrollable map so the last pixels can scroll above the overlay footer.
  double _mapScrollBottomInset(BuildContext context) {
    if (!_footerVisible) return 24;
    return MediaQuery.viewPaddingOf(context).bottom + 136;
  }

  bool _journeyMentionsQuba() {
    for (final l in _landmarks) {
      if (l.name.toLowerCase().contains('quba')) return true;
    }
    for (final v in _knownRegionTitles.values) {
      if (v.toLowerCase().contains('quba')) return true;
    }
    return false;
  }

  /// After the final map challenge; if the journey includes Quba, its challenge must be done too.
  bool get _showFinishJourneyInFooter {
    if (!_lastRegionChallengeCompleted) return false;
    if (_journeyMentionsQuba()) return _qubaChallengeCompleted;
    return true;
  }

  /// Firestore `journeys` document id (e.g. `journey_1`). Inferred from [landmarksJourneyId] when omitted (`journey1` → `journey_1`).
  String? _effectiveCatalogJourneyId() {
    final c = widget.catalogJourneyId?.trim();
    if (c != null && c.isNotEmpty) return c;
    final lm = widget.landmarksJourneyId.trim();
    final m = RegExp(r'^journey(\d+)$').firstMatch(lm);
    if (m != null) return 'journey_${m.group(1)}';
    return null;
  }

  Future<void> _loadJourneyNameFromFirestore() async {
    final id = _effectiveCatalogJourneyId();
    if (id == null || id.isEmpty) return;
    try {
      final journey = await JourneyDataSource().getById(id);
      if (!mounted || journey == null) return;
      _catalogJourney = journey;
      final name = journey.name.trim();
      // Do not overwrite a non-default [journeyTitle] with the model fallback "Journey".
      if (name.isEmpty || name == 'Journey') return;
      setState(() => _journeyNameFromDb = name);
      _schedulePersistProgress();
    } catch (_) {
      // Keep [widget.journeyTitle] as fallback.
    }
  }

  String _appBarTitle() => _journeyNameFromDb ?? widget.journeyTitle;

  Future<void> _loadLandmarks() async {
    setState(() {
      _landmarksLoading = true;
    });
    try {
      final list = await _landmarkDs.getLandmarksForJourney(widget.landmarksJourneyId);
      final docPairs = await Future.wait(
        _regionLandmarkDocumentIds.entries.map((e) async {
          final lm = await _landmarkDs.getLandmark(e.value);
          return MapEntry(e.key, lm);
        }),
      );
      final byDoc = <int, JourneyLandmark>{
        for (final e in docPairs)
          if (e.value != null) e.key: e.value!,
      };
      if (!mounted) return;
      setState(() {
        _landmarks = list;
        _regionLandmarksByDocumentId
          ..clear()
          ..addAll(byDoc);
        _landmarksLoading = false;
      });
      // Pre-resolve and precache images in the background to eliminate the 1–2s delay
      // when opening a region sheet for the first time.
      Future<void>(() async {
        try {
          await prewarmPlaceImageResolver();
          if (!mounted) return;
          final names = <String>{
            for (final l in list) l.name,
            ..._knownRegionTitles.values,
          };
          for (final name in names) {
            final path = await resolvePlaceImageAsset(name);
            if (!mounted || path == null) continue;
            await precacheImage(AssetImage(path), context);
          }
        } catch (_) {}
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedulePersistProgress();
      });
    } on FirebaseException catch (_) {
      if (!mounted) return;
      setState(() {
        _landmarks = [];
        _regionLandmarksByDocumentId.clear();
        _landmarksLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _landmarks = [];
        _regionLandmarksByDocumentId.clear();
        _landmarksLoading = false;
      });
    }
  }

  /// Landmark for this SVG region: explicit **document id** map first, then [order] == region.
  JourneyLandmark? _landmarkForRegion(int region) {
    final byDoc = _regionLandmarksByDocumentId[region];
    if (byDoc != null) return byDoc;

    for (final l in _landmarks) {
      if (l.order == region) return l;
    }

    final docId = _regionLandmarkDocumentIds[region];
    if (docId != null) {
      for (final l in _landmarks) {
        if (l.documentId == docId) return l;
      }
    }
    return null;
  }

  /// Firestore name, then known title (e.g. region 8 → Bustan Al-Mustazil), else generic.
  String _placeTitle(int region) {
    final lm = _landmarkForRegion(region);
    if (lm != null) return lm.name;
    return _knownRegionTitles[region] ?? 'Region $region';
  }

  String _footerPlaceName() {
    if (_landmarksLoading) return 'Loading place…';
    return _placeTitle(currentRegion);
  }

  bool _canOpenMapsForCurrentRegion() {
    if (_landmarksLoading) return false;
    final lm = _landmarkForRegion(currentRegion);
    return lm != null && lm.hasCoordinates;
  }

  Future<void> _openGoogleMapsForCurrentRegion() async {
    final lm = _landmarkForRegion(currentRegion);
    if (lm == null || !lm.hasCoordinates) return;
    final ok = await LandmarkMapsLaunchService.openWalkingDirections(
      latitude: lm.latitude!,
      longitude: lm.longitude!,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _openSignInForFinish() {
    Navigator.of(context)
        .push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const LoginScreen(returnToCallerOnSuccess: true),
          ),
        )
        .then((signedIn) {
      if (signedIn == true && mounted) setState(() {});
    });
  }

  Future<void> _finishJourneyAndFeedback() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _openSignInForFinish();
      return;
    }
    final journeyId = _effectiveCatalogJourneyId();
    if (journeyId == null || journeyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine this journey. Try again from the journey list.')),
      );
      return;
    }
    try {
      await JourneyCompletionDataSource().markCompleted(
        userId: uid,
        journeyId: journeyId,
      );
      try {
        await _progressDs.delete(userId: uid, journeyId: journeyId);
      } catch (_) {}
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => FeedbackScreen(journeyId: journeyId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toUserFriendlyMessage(e))),
      );
    }
  }

  void _onEmptyChallengeOverlayNext() {
    final r = currentRegion;
    final name = _placeTitle(r).toLowerCase();
    setState(() {
      _emptyChallengeOverlay = false;
      if (name.contains('quba')) _qubaChallengeCompleted = true;
      if (r >= _mapRegionCount) _lastRegionChallengeCompleted = true;
      if (r < _mapRegionCount) currentRegion += 1;
    });
    _schedulePersistProgress();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _leaveMapToJourneyIntro();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _appBarTitle(),
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.green,
        centerTitle: true,
        foregroundColor: AppColors.brown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.brown),
          onPressed: _leaveMapToJourneyIntro,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: AppColors.beige,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const svgWidth = 430.0;
                  const svgHeight = 850.0;
                  final w = constraints.maxWidth;
                  final h = w * (svgHeight / svgWidth);
                  const topInset = 6.0;
                  final bottomInset = _mapScrollBottomInset(context);
                  final maxH = constraints.maxHeight;

                  final map = SizedBox(
                    width: w,
                    height: h,
                    child: JourneySvgMap(
                      assetPath: 'images/map.svg',
                      activeMapAssetPath: 'images/map_active.png',
                      inactiveMapAssetPath: 'images/map_inactive.png',
                      regionCount: _mapRegionCount,
                      currentRegion: currentRegion,
                      allowTapInactive: true,
                      onRegionTap: _onRegionTap,
                    ),
                  );

                  // When the body is taller than the map, a plain [SingleChildScrollView]
                  // leaves beige below the map; pin the map to the bottom (above the footer inset).
                  if (topInset + h + bottomInset <= maxH) {
                    return Padding(
                      padding: const EdgeInsets.only(top: topInset),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: map,
                            ),
                          ),
                          SizedBox(height: bottomInset),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: topInset,
                      bottom: bottomInset,
                    ),
                    child: map,
                  );
                },
              ),
            ),
          ),
          if (_footerVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Material(
                  elevation: 10,
                  color: AppColors.beige,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_showFinishJourneyInFooter) ...[
                          Text(
                            _footerPlaceName(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kReadableBody,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_showFinishJourneyInFooter)
                          FilledButton.icon(
                            onPressed: _finishJourneyAndFeedback,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(64, 52),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.rate_review_outlined, size: 22, color: Colors.white),
                            label: const Text(
                              'Finish Journey & Leave Feedback',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.2),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          FilledButton.icon(
                            onPressed: _canOpenMapsForCurrentRegion()
                                ? _openGoogleMapsForCurrentRegion
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(64, 52),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined, size: 22, color: Colors.white),
                            label: const Text(
                              'Open in Google Maps',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_regionSheetRegion != null) _buildRegionSheet(context),
          if (_emptyChallengeOverlay) _buildEmptyChallengeOverlay(context),
          if (_centerMessage != null) _buildCenterMessageOverlay(),
        ],
      ),
    ),
    );
  }

  Widget _buildCenterMessageOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.beige,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.brown.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _centerMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _kReadableBody,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChallengeOverlay(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final lm = _landmarkForRegion(currentRegion);
    final challenge = lm?.challenge;
    if (challenge == null && !_noChallengeAutoAdvanceScheduled) {
      _noChallengeAutoAdvanceScheduled = true;
      Future<void>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 950));
        if (mounted && _emptyChallengeOverlay) _onEmptyChallengeOverlayNext();
      });
    }
    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        child: Center(
          child: Container(
            width: size.width * 0.88,
            height: size.height * 0.72,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.beige,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.brown.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: challenge != null
                        ? ChallengeRenderer(
                            challenge: challenge,
                            currentRegionOrder: currentRegion,
                            resolveNextDestination: () async {
                              // Next stop = document in `nextLandmarkId` on the **current** landmark when set;
                              // otherwise infer by region order. Route fields live on the **next** landmark doc.
                              final nextDocId = lm?.nextLandmarkId?.trim();
                              JourneyLandmark? nextLm;
                              if (nextDocId != null && nextDocId.isNotEmpty) {
                                for (final l in _landmarks) {
                                  if (l.documentId == nextDocId) {
                                    nextLm = l;
                                    break;
                                  }
                                }
                                if (nextLm == null) {
                                  try {
                                    nextLm = await _landmarkDs.getLandmark(nextDocId);
                                  } catch (_) {}
                                }
                              }
                              final nextRegion = (nextLm?.order ?? (currentRegion + 1));
                              if (nextRegion > _mapRegionCount) {
                                return ChallengeNextDestination(
                                  name: 'Journey completed!',
                                  isLastRegion: true,
                                );
                              }
                              final byOrder = _landmarkForRegion(nextRegion);
                              final nextResolved = nextLm ?? byOrder;
                              final name =
                                  nextResolved?.name ?? byOrder?.name ?? 'Region $nextRegion';
                              final dist = nextResolved?.distanceFromPreviousMeters ??
                                  byOrder?.distanceFromPreviousMeters;
                              var walk = nextResolved?.walkingTimeFromPreviousMinutes ??
                                  byOrder?.walkingTimeFromPreviousMinutes;

                              // Re-read from Firestore when model missed walking (key casing, web num type, etc.).
                              if (walk == null) {
                                final fetchId = nextResolved?.documentId ?? byOrder?.documentId;
                                if (fetchId != null) {
                                  try {
                                    final snap = await FirebaseFirestore.instance
                                        .collection(JourneyLandmarkDataSource.collection)
                                        .doc(fetchId)
                                        .get();
                                    final d = snap.data();
                                    if (d != null) {
                                      walk = JourneyLandmark.walkingTimeFromPreviousMinutesFromRawMap(
                                        d,
                                        debugDocId: fetchId,
                                      );
                                      if (kDebugMode && walk == null) {
                                        debugPrint(
                                          '[ChallengeNext] walkingStillNull doc=$fetchId '
                                          'keys=${d.keys.toList()} '
                                          'distanceRaw=${d[JourneyLandmark.firestoreFieldDistanceFromPreviousMeters]}',
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (kDebugMode) debugPrint('[ChallengeNext] walking refetch: $e');
                                  }
                                }
                              }

                              if (kDebugMode) {
                                debugPrint(
                                  '[ChallengeNext] nextLandmarkId=${nextDocId ?? 'null'} '
                                  'inferredRegion=$nextRegion resolvedDoc=${nextResolved?.documentId} '
                                  'parsedWalking=$walk',
                                );
                              }

                              return ChallengeNextDestination(
                                name: name,
                                distanceFromPreviousMeters: dist,
                                walkingTimeFromPreviousMinutes: walk,
                                isLastRegion: currentRegion >= _mapRegionCount,
                              );
                            },
                            onResultNext: _onEmptyChallengeOverlayNext,
                            nextLandmarkDocumentId: lm?.nextLandmarkId,
                            onChallengeResolved: ({required success, nextLandmarkDocumentId}) {
                              if (!success) return;
                              // TODO: Navigate using [nextLandmarkDocumentId] when journey routing supports it.
                            },
                          )
                        : Center(
                            child: Text(
                              'Challenge coming soon.',
                              style: TextStyle(
                                color: AppColors.brown.withValues(alpha: 0.75),
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegionSheet(BuildContext context) {
    final region = _regionSheetRegion!;
    final title = _landmarksLoading ? 'Region $region' : _placeTitle(region);
    final lm = _landmarkForRegion(region);
    final description = lm?.description?.trim();
    final size = MediaQuery.sizeOf(context);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _regionSheetRegion = null),
        child: Material(
          color: Colors.black.withValues(alpha: 0.35),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: _RegionLandmarkChallengeSheet(
                width: size.width * 0.92,
                height: size.height * 0.88,
                title: title,
                description: description,
                onClose: () => setState(() => _regionSheetRegion = null),
                onGoChallenge: () {
                  setState(() {
                    _regionSheetRegion = null;
                    _emptyChallengeOverlay = true;
                    _noChallengeAutoAdvanceScheduled = false;
                  });
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onRegionTap(int region) {
    if (_emptyChallengeOverlay || _regionSheetRegion != null) return;

    if (region > currentRegion) {
      _showCenterMessage("You haven't reached this stage yet");
      return;
    }
    if (region < currentRegion) {
      _showCenterMessage('This stage is done');
      return;
    }
    setState(() => _regionSheetRegion = region);
  }
}

/// Region popup: close (left), centered title, short countdown (right), description, then challenge CTA.
class _RegionLandmarkChallengeSheet extends StatefulWidget {
  const _RegionLandmarkChallengeSheet({
    required this.width,
    required this.height,
    required this.title,
    required this.description,
    required this.onClose,
    required this.onGoChallenge,
  });

  final double width;
  final double height;
  final String title;
  final String? description;
  final VoidCallback onClose;
  final VoidCallback onGoChallenge;

  @override
  State<_RegionLandmarkChallengeSheet> createState() => _RegionLandmarkChallengeSheetState();
}

class _RegionLandmarkChallengeSheetState extends State<_RegionLandmarkChallengeSheet> {
  static const int _initialSeconds = 5;
  int _secondsLeft = _initialSeconds;
  Timer? _timer;
  String? _placeImageAsset;
  bool _imageLoading = false;

  Future<void> _loadPlaceImage() async {
    setState(() {
      _placeImageAsset = null;
      _imageLoading = true;
    });
    final path = await resolvePlaceImageAsset(widget.title);
    if (!mounted) return;
    setState(() {
      _placeImageAsset = path;
      _imageLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPlaceImage();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) _secondsLeft--;
      });
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _RegionLandmarkChallengeSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title.trim() != widget.title.trim()) {
      _loadPlaceImage();
    }
  }

  String _formatCountdown() {
    final s = _secondsLeft.clamp(0, _initialSeconds);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  Widget _descriptionBody() {
    final desc = widget.description;
    if (desc == null || desc.trim().isEmpty) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: 'Add a description for this landmark in Firestore (field: description).',
          style: TextStyle(
            fontSize: 16,
            height: 1.58,
            color: _kReadableBody.withValues(alpha: 0.52),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final paras = _splitDescriptionParagraphs(desc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < paras.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.start,
            text: TextSpan(children: _readableSpans(paras[i])),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final challengeReady = _secondsLeft <= 0;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.close, color: _kReadableBody.withValues(alpha: 0.88), size: 24),
                    tooltip: 'Close',
                    onPressed: widget.onClose,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 100),
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kReadableBody,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.brown.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Text(
                          _formatCountdown(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            color: challengeReady ? AppColors.orange : _kReadableBody.withValues(alpha: 0.82),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.brown.withValues(alpha: 0.14)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Align(
                alignment: Alignment.topCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.88,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_placeImageAsset != null || _imageLoading) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _placeImageAsset != null
                                ? Image.asset(
                                    _placeImageAsset!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: AppColors.brown.withValues(alpha: 0.06),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Image failed to load',
                                        style: TextStyle(
                                          color: AppColors.brown.withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: AppColors.brown.withValues(alpha: 0.06),
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.brown.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _descriptionBody(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: challengeReady ? widget.onGoChallenge : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.88),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: challengeReady ? 3 : 1,
                    shadowColor: AppColors.brown.withValues(alpha: 0.35),
                  ),
                  icon: Icon(
                    Icons.flag_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: challengeReady ? 1 : 0.88),
                  ),
                  label: Text(
                    'Start Challenge',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.2,
                      color: Colors.white.withValues(alpha: challengeReady ? 1 : 0.9),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
