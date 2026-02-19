import 'package:flutter/material.dart';

import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../../model/app_user.dart';

/// Empty landing page for both user and admin after sign in or create account.
/// Shows role and a Log out button that returns to the login page.
class HomePage extends StatelessWidget {
  final AppUser user;

  const HomePage({super.key, required this.user});

  Future<void> _logout(BuildContext context) async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
    // AuthGate will rebuild and show LoginScreen
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
              'Role: ${user.role}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
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
