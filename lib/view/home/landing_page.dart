import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../auth/login_screen.dart';
import '../journey/journey_purchase_screen.dart';

/// Public landing page - no sign-in required. Shows Sign In and Journeys buttons.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void _openSignIn(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _openJourneys(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const JourneyPurchaseScreen(),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('MaSeerah'),
            actions: user != null
                ? [
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _logout(context),
                      tooltip: 'Log out',
                    ),
                  ]
                : null,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome to MaSeerah',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Explore journeys and discover new experiences.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    onPressed: () => _openJourneys(context),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Journeys'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (user == null)
                    OutlinedButton.icon(
                      onPressed: () => _openSignIn(context),
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
