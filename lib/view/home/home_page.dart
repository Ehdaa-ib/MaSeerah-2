import 'package:flutter/material.dart';

import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../../model/app_user.dart';
import '../journey/journey_purchase_screen.dart';

/// Landing page after sign in. Shows journey purchase and log out.
class HomePage extends StatelessWidget {
  final AppUser user;

  const HomePage({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
  }

  void _openJourney(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyPurchaseScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MaSeerah'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Hello, ${user.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openJourney(context),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Journeys'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
