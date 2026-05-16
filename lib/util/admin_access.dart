import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/validators.dart';
import 'wait_for_auth.dart';

/// Resolves whether the signed-in user may use the admin dashboard and
/// privileged Firestore reads/writes (email allowlist or `users.role == admin`).
class AdminAccess {
  AdminAccess._();

  static Future<bool> isAdminUser() async {
    await waitForAuth();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final email = user.email?.trim() ?? '';
    if (email.isNotEmpty && Validators.isAdminEmail(email)) {
      return true;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists || doc.data() == null) return false;
      final role = (doc.data()!['role'] as String?)?.trim().toLowerCase();
      return role == 'admin';
    } catch (_) {
      return false;
    }
  }
}
