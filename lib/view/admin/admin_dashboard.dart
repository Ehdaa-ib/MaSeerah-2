import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../../util/admin_access.dart';
import '../auth/login_screen.dart';
import '../home/landing_page.dart';
import 'pages/admin_dashboard_home_page.dart';
import 'pages/admin_feedback_page.dart';
import 'pages/admin_journeys_page.dart';
import 'pages/admin_recommendations_page.dart';
import 'pages/admin_users_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _index = 0;
  bool _checkingAccess = true;
  bool _accessDenied = false;

  static const _destinations = <_AdminDestination>[
    _AdminDestination(label: 'Dashboard', icon: Icons.dashboard_rounded),
    _AdminDestination(label: 'Users', icon: Icons.people_alt_rounded),
    _AdminDestination(label: 'Journeys', icon: Icons.travel_explore_rounded),
    _AdminDestination(label: 'Feedback', icon: Icons.feedback_outlined),
    _AdminDestination(label: 'Places', icon: Icons.storefront_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    try {
      final allowed = await AdminAccess.isAdminUser();
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _accessDenied = !allowed;
      });
      if (!allowed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingAccess = false;
        _accessDenied = true;
      });
    }
  }

  Future<void> _logout() async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LandingPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: AppColors.green,
        body: Center(child: CircularProgressIndicator(color: AppColors.brown)),
      );
    }

    if (_accessDenied) {
      return const Scaffold(
        backgroundColor: AppColors.green,
        body: Center(
          child: Text(
            'Admin access required.',
            style: TextStyle(
              color: AppColors.brown,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 980;
    final title = _destinations[_index].label;

    final body = switch (_index) {
      0 => const AdminDashboardHomePage(),
      1 => const AdminUsersPage(),
      2 => const AdminJourneysPage(),
      3 => const AdminFeedbackPage(),
      _ => const AdminRecommendationsPage(),
    };

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: AppColors.beige,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _AdminDrawerHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _destinations.length,
                        itemBuilder: (context, i) {
                          final d = _destinations[i];
                          final selected = i == _index;
                          return ListTile(
                            leading: Icon(d.icon, color: AppColors.brown),
                            title: Text(
                              d.label,
                              style: TextStyle(
                                color: AppColors.brown,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            selectedTileColor: AppColors.green.withOpacity(
                              0.25,
                            ),
                            onTap: () {
                              setState(() => _index = i);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.person, color: AppColors.brown),
                      title: Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'Admin',
                        style: const TextStyle(color: AppColors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 260,
              color: AppColors.beige,
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    const _AdminDrawerHeader(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _destinations.length,
                        itemBuilder: (context, i) {
                          final d = _destinations[i];
                          final selected = i == _index;
                          return ListTile(
                            leading: Icon(d.icon, color: AppColors.brown),
                            title: Text(
                              d.label,
                              style: TextStyle(
                                color: AppColors.brown,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            selectedTileColor: AppColors.green.withOpacity(
                              0.25,
                            ),
                            onTap: () => setState(() => _index = i),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.person, color: AppColors.brown),
                      title: Text(
                        FirebaseAuth.instance.currentUser?.email ?? 'Admin',
                        style: const TextStyle(color: AppColors.brown),
                      ),
                      subtitle: const Text(
                        'Signed in',
                        style: TextStyle(color: AppColors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _AdminDestination {
  final String label;
  final IconData icon;
  const _AdminDestination({required this.label, required this.icon});
}

class _AdminDrawerHeader extends StatelessWidget {
  const _AdminDrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brown,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AppColors.beige,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MaSeerah Admin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Dashboard',
                  style: TextStyle(fontSize: 12, color: AppColors.brown),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
