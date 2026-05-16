import 'package:firebase_auth/firebase_auth.dart';

/// Blocks until [FirebaseAuth.instance.currentUser] is non-null so Firestore
/// rules that require authentication do not run against a null user session.
Future<void> waitForAuth({
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (FirebaseAuth.instance.currentUser == null) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Not signed in. Please sign in again.');
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
