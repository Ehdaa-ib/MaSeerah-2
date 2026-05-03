import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/repoImp/journey_repository_firebase.dart';
import '../../model/journey.dart';
import '../auth/login_screen.dart';
import '../journey/journey_list_screen.dart';
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
  bool _loading = true;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final journeys = await _journeyRepo.getAll();
      if (mounted) {
        setState(() {
          _journeys = journeys;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
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
              );
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

  void _openJourney(Journey? journey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyPurchaseScreen(
          journeyId: journey?.journeyId ?? 'journey_1',
          initialJourney: journey,
        ),
      ),
    );
  }

  void _openActiveJourneys() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JourneyListScreen()),
    );
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
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.brown))
                        : _buildJourneyCards(),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: _selectedNavIndex,
            onHomeTap: () => setState(() => _selectedNavIndex = 0),
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
                    hintText: 'Explore your next journey',
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
    // Card 0: Darb Al-Sunnah (linked to journey_1), 1: Battle of Uhud, 2: Valley Adventure
    final journey1 = _journeys.where((j) => j.journeyId == 'journey_1');
    final darbJourney = journey1.isNotEmpty ? journey1.first : (_journeys.isNotEmpty ? _journeys.first : null);
    final q = _searchController.text.trim().toLowerCase();
    final visibleIndices = _getVisibleCardIndices(q);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: visibleIndices.length,
      itemBuilder: (context, i) {
        final index = visibleIndices[i];
        return _JourneyCard(
          imagePath: _imagePathForIndex(index),
          onTap: index == 0 ? () => _openJourney(darbJourney ?? (_journeys.isNotEmpty ? _journeys.first : null)) : null,
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
        return 'images/the-vally-advanture.png';
      default:
        return 'images/image3.png';
    }
  }

}

class _JourneyCard extends StatelessWidget {
  final String imagePath;
  final VoidCallback? onTap;

  const _JourneyCard({
    required this.imagePath,
    this.onTap,
  });

  Widget _buildCardContent() {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      width: double.infinity,
      height: 280,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
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
