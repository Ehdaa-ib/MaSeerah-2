import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/app_user.dart';
import 'create_account_screen.dart';
import 'login_screen.dart';
import '../home/home_page.dart';

/// Root auth-aware screen: shows Login/Create account when signed out,
/// or User/Admin home when signed in. Logout brings back to login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) {
          return Navigator(
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/create':
                  return MaterialPageRoute(
                    builder: (_) => const CreateAccountScreen(),
                  );
                case '/login':
                default:
                  return MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  );
              }
            },
            initialRoute: '/login',
          );
        }
        return _SignedInGate(uid: user.uid);
      },
    );
  }
}

class _SignedInGate extends StatelessWidget {
  final String uid;

  const _SignedInGate({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading user profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Check Firestore security rules allow authenticated users to read users/{uid}.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (!snapshot.data!.exists) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User profile not found.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try logging out and creating an account again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        
        final rawData = snapshot.data!.data();
        if (rawData == null || rawData is! Map) {
          return Scaffold(
            body: Center(
              child: Text(
                'User profile not found.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        
        final data = Map<String, dynamic>.from(rawData);
        if (data.isEmpty) {
          return Scaffold(
            body: Center(
              child: Text(
                'User profile not found.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        
        final map = Map<String, dynamic>.from(data);
        map['userId'] = snapshot.data!.id;
        
        // Ensure required fields exist
        if (map['email'] == null || map['name'] == null || map['role'] == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'User profile incomplete.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        
        final appUser = AppUser.fromMap(map);
        return HomePage(user: appUser);
      },
    );
  }
}
