import 'package:firebase_auth/firebase_auth.dart';

/// Blocks until [FirebaseAuth.instance.currentUser] is non-null so Firestore
/// rules that require authentication do not run against a null user session.
Future<void> waitForAuth() async {
  while (FirebaseAuth.instance.currentUser == null) {
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
