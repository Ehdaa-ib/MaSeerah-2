import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/repoImp/journey_repository_firebase.dart';
import '../../model/journey.dart';
import '../auth/login_screen.dart';
import '../journey/journey_list_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_bottom_nav.dart';
import 'profile_screen.dart';
import '../journey/journey_purchase_screen.dart';

/// Home page with search bar, scrollable journey cards, and bottom nav.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _journeyRepo = JourneyRepositoryFirebase(JourneyDataSource());
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  List<Journey> _journeys = [];
  int _selectedNavIndex = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final journeys = await _journeyRepo.getAll();
      if (mounted) {
        setState(() => _journeys = journeys);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[LandingPage] journey catalog load failed: $e');
    }
  }

  void _openSignIn() {
    final landingContext = context;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (sheetContext) => LoginScreen(
          hideBackButton: true,
          authBottomNav: AppBottomNav(
            selectedIndex: 2,
            onHomeTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _selectedNavIndex = 0);
            },
            onActiveJourneysTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _selectedNavIndex = 1);
              Navigator.of(landingContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => const JourneyListScreen(),
                ),
              ).then((_) {
                if (mounted) setState(() => _selectedNavIndex = 0);
              });
            },
            onProfileTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _selectedNavIndex = 2);
            },
          ),
        ),
      ),
    );
  }

  /// Home marketing cards → Firestore `journeys/{id}` (index 0 = Darb Al-Sunnah → `journey_1`).
  static const List<String> _homeCardJourneyIds = [
    'journey_1',
    'journey_2',
    'journey_3',
  ];

  static String _journeyIdForIndex(int index) {
    if (index >= 0 && index < _homeCardJourneyIds.length) {
      return _homeCardJourneyIds[index];
    }
    return 'journey_1';
  }

  Journey? _catalogJourneyForCard(int index) {
    final target = _journeyIdForIndex(index);
    final cached = JourneyDataSource.findInCatalogCache(target);
    if (cached != null) return cached;

    final targetVariants = JourneyDataSource.docIdVariants(target).toSet();
    for (final j in _journeys) {
      for (final variant in JourneyDataSource.docIdVariants(j.journeyId)) {
        if (targetVariants.contains(variant)) return j;
      }
    }
    return null;
  }

  Journey _stubJourneyForCard(int index) {
    final info = _journeyCardInfoForIndex(context, index);
    return Journey(
      journeyId: _journeyIdForIndex(index),
      name: info.title,
      price: 0,
      estimatedDuration: info.duration,
      stops: info.stops,
    );
  }

  Future<void> _openJourneyForCard(int index) async {
    final journeyId = _journeyIdForIndex(index);
    var journey = _catalogJourneyForCard(index) ?? _stubJourneyForCard(index);

    try {
      final fresh = await _journeyRepo.getById(journeyId);
      if (fresh != null) {
        journey = fresh;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LandingPage] getById($journeyId) failed: $e');
      }
    }

    if (!mounted) return;
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => JourneyPurchaseScreen(
          journeyId: journeyId,
          initialJourney: journey,
        ),
      ),
    );
  }

  void _openActiveJourneys() {
    setState(() => _selectedNavIndex = 1);
    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(builder: (_) => const JourneyListScreen()),
    )
        .then((_) {
      if (mounted) setState(() => _selectedNavIndex = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          backgroundColor: AppColors.green,
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('images/image3.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(child: _buildJourneyCards()),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: _selectedNavIndex,
            onHomeTap: () {
              setState(() => _selectedNavIndex = 0);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            onActiveJourneysTap: _openActiveJourneys,
            onProfileTap: () {
              setState(() => _selectedNavIndex = 2);
              if (user != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) {
                  if (mounted) setState(() => _selectedNavIndex = 0);
                });
              } else {
                _openSignIn();
              }
            },
          ),
        );
      },
    );
  }

  /// Header + search combined in one beige box
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MaSeerah',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.landingSearchExplore,
                    hintStyle: TextStyle(
                      color: AppColors.brown,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: AppColors.brown,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _searchFocusNode.requestFocus(),
            icon: Icon(Icons.search, color: AppColors.brown, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyCards() {
    final q = _searchController.text.trim().toLowerCase();
    final visibleIndices = _getVisibleCardIndices(q);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 100),
      itemCount: visibleIndices.length,
      itemBuilder: (context, i) {
        final index = visibleIndices[i];
        final info = _journeyCardInfoForIndex(context, index);
        return _JourneyCard(
          imagePath: _imagePathForIndex(index),
          title: info.title,
          rating: info.rating,
          duration: info.duration,
          stopsLabel: info.stops,
          onTap: () => unawaited(_openJourneyForCard(index)),
        );
      },
    );
  }

  /// Filter cards by search: darb/alsunnah, uhud/battle, valley/adventure
  List<int> _getVisibleCardIndices(String q) {
    if (q.isEmpty) return [0, 1, 2];
    final indices = <int>[];
    if (q.contains('darb') || q.contains('alsunnah') || q.contains('sunnah')) indices.add(0);
    if (q.contains('uhud') || q.contains('battle')) indices.add(1);
    if (q.contains('valley') || q.contains('adventure') || q.contains('vally') || q.contains('journey')) indices.add(2);
    return indices.isEmpty ? [0, 1, 2] : indices;
  }

  /// First: Darb Al-Sunnah, second: Battle of Uhud, third: Valley Adventure
  static String _imagePathForIndex(int index) {
    switch (index) {
      case 0:
        return 'images/darb-alsunnah.png';
      case 1:
        return 'images/the-battle-of-uhud.png';
      case 2:
        return 'images/the-vally-advanture.jpg';
      default:
        return 'images/image3.png';
    }
  }

  /// Display order: Darb, Uhud, Valley — matches [_imagePathForIndex].
  _JourneyCardInfo _journeyCardInfoForIndex(BuildContext context, int index) {
    final l10n = AppLocalizations.of(context)!;
    switch (index) {
      case 0:
        return _JourneyCardInfo(
          title: l10n.landingCardDarbTitle,
          rating: 4.9,
          duration: l10n.landingCardDuration3h,
          stops: l10n.landingCardStops8,
        );
      case 1:
        return _JourneyCardInfo(
          title: l10n.landingCardUhudTitle,
          rating: 4.5,
          duration: l10n.landingCardDuration2h,
          stops: l10n.landingCardStops5,
        );
      case 2:
        return _JourneyCardInfo(
          title: l10n.landingCardValleyTitle,
          rating: 4.3,
          duration: l10n.landingCardDuration1_5h,
          stops: l10n.landingCardStops3,
        );
      default:
        return const _JourneyCardInfo(
          title: '',
          rating: 0,
          duration: '',
          stops: '',
        );
    }
  }

}

class _JourneyCardInfo {
  final String title;
  final double rating;
  final String duration;
  final String stops;

  const _JourneyCardInfo({
    required this.title,
    required this.rating,
    required this.duration,
    required this.stops,
  });
}

class _JourneyCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final double rating;
  final String duration;
  final String stopsLabel;
  final VoidCallback? onTap;

  const _JourneyCard({
    required this.imagePath,
    required this.title,
    required this.rating,
    required this.duration,
    required this.stopsLabel,
    this.onTap,
  });

  static const _detailStyle = TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );

  Widget _buildCardContent() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 0,
                    runSpacing: 4,
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(width: 4),
                      Text(rating.toStringAsFixed(1), style: _detailStyle),
                      Text('  |  ', style: _detailStyle.copyWith(color: Colors.white70)),
                      Text(duration, style: _detailStyle),
                      Text('  |  ', style: _detailStyle.copyWith(color: Colors.white70)),
                      Text(stopsLabel, style: _detailStyle),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _buildCardContent();
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }
}
