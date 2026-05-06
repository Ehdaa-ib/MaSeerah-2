import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/login_screen.dart';
import '../home/landing_page.dart';
import '../home/profile_screen.dart';
import 'journey_map_screen.dart';

/// In-progress journeys only (footer **Active Journeys** tab). Browse/purchase uses the home journey cards.
class JourneyListScreen extends StatelessWidget {
  const JourneyListScreen({super.key});

  void _openActiveProgress(BuildContext context, ActiveJourneyProgress p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JourneyMapScreen(
          journeyTitle: p.journeyTitle,
          landmarksJourneyId: p.landmarksJourneyId,
          catalogJourneyId: p.catalogJourneyId ?? p.journeyId,
          initialRegion: p.currentRegion,
          initialQubaChallengeCompleted: p.qubaChallengeCompleted,
          initialLastRegionChallengeCompleted: p.lastRegionChallengeCompleted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressDs = JourneyProgressDataSource();

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: const Text(
          'Active Journeys',
          style: TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.w800,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brown));
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
                        Icon(Icons.info_outline, color: AppColors.brown.withValues(alpha: 0.85)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Sign in to see journeys you have in progress. Your place is saved when you leave the map.',
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
            stream: progressDs.streamAll(userId: uid),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: AppColors.brown));
              }
              final active = snap.data ?? [];
              if (active.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route_outlined, size: 72, color: AppColors.brown.withValues(alpha: 0.45)),
                        const SizedBox(height: 20),
                        Text(
                          'No active journeys',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brown.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'When you start a journey and step away, it will appear here so you can continue.',
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          'Current stop: ${p.currentRegion}',
                          style: TextStyle(color: AppColors.brown.withValues(alpha: 0.75)),
                        ),
                      ),
                      trailing: const Icon(Icons.play_arrow_rounded, color: AppColors.orange, size: 32),
                      onTap: () => _openActiveProgress(context, p),
                    ),
                  );
                },
              );
            },
          );
        },
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
