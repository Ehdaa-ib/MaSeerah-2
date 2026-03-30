import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../../model/app_user.dart';
import '../../widgets/app_bottom_nav.dart';
import '../auth/login_screen.dart';
import '../journey/journey_list_screen.dart';

/// Profile page when user is signed in. Shows greeting, logout icon.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Not signed in',
            style: TextStyle(color: AppColors.brown),
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache)),
      builder: (context, snapshot) {
        String userName = 'User';
        if (snapshot.hasData &&
            snapshot.data!.exists &&
            snapshot.data!.data() != null) {
          final data = Map<String, dynamic>.from(snapshot.data!.data() as Map);
          data['userId'] = snapshot.data!.id;
          final appUser = AppUser.fromMap(data);
          userName = appUser.name;
        }

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('images/image3.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      color: AppColors.brown,
                      iconSize: 32,
                      onPressed: () => _logoutAndGoToSignIn(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Hello $userName',
                        style: const TextStyle(
                          color: AppColors.brown,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 2,
            onHomeTap: () => Navigator.of(context).pop(),
            onActiveJourneysTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JourneyListScreen()),
              );
            },
            onProfileTap: () {},
          ),
        );
      },
    );
  }

  Future<void> _logoutAndGoToSignIn(BuildContext context) async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }
}
