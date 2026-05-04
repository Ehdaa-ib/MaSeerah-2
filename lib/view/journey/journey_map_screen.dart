import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/firebase/journey_landmark_data_source.dart';
import '../../model/journey_landmark.dart';
import '../../service/landmark_maps_launch_service.dart';
import 'widgets/journey_svg_map.dart';

class JourneyMapScreen extends StatefulWidget {
  const JourneyMapScreen({
    super.key,
    /// Shown in the app bar until [catalogJourneyId] load completes (if any).
    this.journeyTitle = 'Journey',
    /// `journeyId` on `journey_landmarks` documents (Firestore).
    this.landmarksJourneyId = 'journey1',
    /// Document id in `journeys` (e.g. `journey_1`); used to load the real journey name.
    this.catalogJourneyId,
  });

  final String journeyTitle;
  final String landmarksJourneyId;
  final String? catalogJourneyId;

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  final _landmarkDs = JourneyLandmarkDataSource();

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

  /// 1-based region index on the SVG; matches Firestore **[order]** (1 → Masjid Al-Nabawi, etc.).
  int currentRegion = 1;

  /// Loaded landmarks; each [JourneyLandmark.order] links to the same-numbered region.
  List<JourneyLandmark> _landmarks = [];

  /// Landmarks loaded by explicit doc id for a region (takes priority over [order] matching).
  final Map<int, JourneyLandmark> _regionLandmarksByDocumentId = {};
  bool _landmarksLoading = true;

  /// When non-null, a full-screen beige sheet is open for this region (footer hidden).
  int? _regionSheetRegion;

  /// Empty "challenge" step after "Go to the challenge" (footer hidden until dismissed).
  bool _emptyChallengeOverlay = false;

  /// Brief centered hint (wrong region / done region).
  String? _centerMessage;
  Timer? _centerMessageTimer;

  /// From `journeys/{catalogJourneyId}`; overrides [widget.journeyTitle] when set.
  String? _journeyNameFromDb;

  @override
  void initState() {
    super.initState();
    _loadLandmarks();
    _loadJourneyNameFromFirestore();
  }

  @override
  void dispose() {
    _centerMessageTimer?.cancel();
    super.dispose();
  }

  void _showCenterMessage(String text) {
    _centerMessageTimer?.cancel();
    setState(() => _centerMessage = text);
    _centerMessageTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _centerMessage = null);
    });
  }

  bool get _footerVisible =>
      _regionSheetRegion == null && !_emptyChallengeOverlay;

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
      final name = journey.name.trim();
      // Do not overwrite a non-default [journeyTitle] with the model fallback "Journey".
      if (name.isEmpty || name == 'Journey') return;
      setState(() => _journeyNameFromDb = name);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _appBarTitle(),
          style: const TextStyle(color: AppColors.brown),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.green,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.brown),
          onPressed: () => Navigator.of(context).pop(),
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

                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: 6,
                      bottom: _footerVisible ? 200 : 24,
                    ),
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: JourneySvgMap(
                        assetPath: 'images/map.svg',
                        activeMapAssetPath: 'images/map_active.png',
                        inactiveMapAssetPath: 'images/map_inactive.png',
                        currentRegion: currentRegion,
                        allowTapInactive: true,
                        onRegionTap: _onRegionTap,
                      ),
                    ),
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 88),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                _footerPlaceName(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brown,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: IntrinsicWidth(
                                  child: FilledButton.icon(
                                    onPressed: _canOpenMapsForCurrentRegion()
                                        ? _openGoogleMapsForCurrentRegion
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 14,
                                      ),
                                      minimumSize: const Size(48, 48),
                                      tapTargetSize: MaterialTapTargetSize.padded,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.map_outlined, size: 22, color: Colors.white),
                                    label: const Text(
                                      'Open in Google Maps',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFBDBDBD),
                                foregroundColor: const Color(0xFF616161),
                                disabledBackgroundColor: const Color(0xFFBDBDBD),
                                disabledForegroundColor: const Color(0xFF616161),
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              onPressed: null,
                              child: const Text('Next'),
                            ),
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
                  color: AppColors.brown,
                  height: 1.35,
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
                const Expanded(child: SizedBox.shrink()),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _emptyChallengeOverlay = false;
                            if (currentRegion < 9) currentRegion += 1;
                          });
                        },
                        child: const Text('Next'),
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
      _showCenterMessage("You haven't reached this stage yet.");
      return;
    }
    if (region < currentRegion) {
      _showCenterMessage('This stage is done.');
      return;
    }
    setState(() => _regionSheetRegion = region);
  }
}

/// Region popup: close (left), centered title, countdown (right), description, then challenge CTA.
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
  static const int _initialSeconds = 2;
  int _secondsLeft = _initialSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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

  String _formatCountdown() {
    final s = _secondsLeft.clamp(0, _initialSeconds);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final challengeReady = _secondsLeft <= 0;
    final desc = widget.description;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          SizedBox(
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: AppColors.brown, size: 26),
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
                      color: AppColors.brown,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      _formatCountdown(),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: challengeReady
                            ? AppColors.orange
                            : AppColors.brown.withValues(alpha: 0.85),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppColors.brown.withValues(alpha: 0.15)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Text(
                (desc != null && desc.isNotEmpty)
                    ? desc
                    : 'Add a description for this landmark in Firestore (field: description).',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: AppColors.brown.withValues(alpha: desc != null && desc.isNotEmpty ? 0.92 : 0.55),
                  fontStyle: desc != null && desc.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: challengeReady ? widget.onGoChallenge : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    disabledForegroundColor: const Color(0xFF616161),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: challengeReady ? 2 : 0,
                    shadowColor: AppColors.brown.withValues(alpha: 0.35),
                  ),
                  child: const Text(
                    'Go to the challenge',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
