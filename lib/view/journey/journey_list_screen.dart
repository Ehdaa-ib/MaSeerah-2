import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../core/app_colors.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../service/journey_inactivity_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/login_screen.dart';
import '../home/landing_page.dart';
import '../home/profile_screen.dart';
import 'journey_map_screen.dart';

/// In-progress journeys only (footer **Active Journeys** tab). Browse/purchase uses the home journey cards.
class JourneyListScreen extends StatefulWidget {
  const JourneyListScreen({super.key});

  @override
  State<JourneyListScreen> createState() => _JourneyListScreenState();
}

class _JourneyListScreenState extends State<JourneyListScreen> {
  final _inactivity = JourneyInactivityService();
  // Perf: reuse one data source (stream subscription) for the screen lifetime.
  final _progressDs = JourneyProgressDataSource();
  String? _lastPurgeUid;

  void _openActiveProgress(BuildContext context, ActiveJourneyProgress p) {
    final catalogId = p.catalogJourneyId ?? p.journeyId;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => JourneyMapScreen(
          journeyTitle: p.journeyTitle,
          landmarksJourneyId: p.landmarksJourneyId,
          catalogJourneyId: catalogId,
          initialRegion: p.currentRegion,
          initialQubaChallengeCompleted: p.qubaChallengeCompleted,
          initialLastRegionChallengeCompleted: p.lastRegionChallengeCompleted,
        ),
      ),
    );
  }

  /// Same chrome as [ProfileScreen._buildHeader] (70px beige bar, rounded bottom).
  Widget _buildHeader(BuildContext context) {
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
      alignment: Alignment.center,
      child: Text(
        AppLocalizations.of(context)!.journeyListTitle,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.brown,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Expanded(
                child: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, authSnap) {
                    if (authSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.brown),
                      );
                    }
                    final uid = authSnap.data?.uid;
                    if (uid == null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Card(
                            color: AppColors.beige,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.brown.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)!.journeyListSignInPrompt,
                                      style: TextStyle(
                                        fontSize: 15,
                                        height: 1.5,
                                        color: AppColors.brown.withValues(alpha: 0.92),
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

                    return StreamBuilder<List<ActiveJourneyProgress>>(
                      stream: _progressDs.streamAll(userId: uid),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Card(
                                color: AppColors.beige,
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.lock_outline,
                                        size: 42,
                                        color: AppColors.brown.withValues(alpha: 0.8),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Could not load your active journeys.',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.brown,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'This is usually caused by Firestore permissions.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.brown.withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: AppColors.brown),
                          );
                        }
                        var active = snap.data ?? [];
                        if (uid != _lastPurgeUid) {
                          _lastPurgeUid = uid;
                          _inactivity.purgeInactiveForUser(uid).then((remaining) {
                            if (!mounted) return;
                            if (remaining.length != active.length) {
                              setState(() {});
                            }
                          });
                        }
                        active = active
                            .where((p) => !_inactivity.isInactive(p))
                            .toList();
                        if (active.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.route_outlined,
                                    size: 72,
                                    color: AppColors.brown.withValues(alpha: 0.45),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    AppLocalizations.of(context)!.journeyListNoActive,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brown.withValues(alpha: 0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    AppLocalizations.of(context)!.journeyListNoActiveSubtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: AppColors.brown.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: active.length,
                          itemBuilder: (context, index) {
                            final p = active[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.beige,
                              elevation: 1,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.orange,
                                  child: const Icon(Icons.route, color: AppColors.beige),
                                ),
                                title: Text(
                                  p.journeyTitle,
                                  style: const TextStyle(
                                    color: AppColors.brown,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    AppLocalizations.of(context)!
                                        .journeyListCurrentStop(p.currentRegion),
                                    style: TextStyle(
                                      color: AppColors.brown.withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.orange,
                                  size: 32,
                                ),
                                onTap: () => _openActiveProgress(context, p),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onHomeTap: () {
          Navigator.of(context).pushAndRemoveUntil<void>(
            MaterialPageRoute<void>(builder: (_) => const LandingPage()),
            (_) => false,
          );
        },
        onActiveJourneysTap: () {},
        onProfileTap: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LoginScreen(returnToCallerOnSuccess: true),
              ),
            );
          }
        },
      ),
    );
  }
}
