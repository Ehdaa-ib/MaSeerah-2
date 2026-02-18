import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/app_user.dart';

class AuthDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    // 1) Create account in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2) Get uid (this is your userID)
    final uid = userCredential.user!.uid;

    // 3) Create AppUser object (profile data)
    final user = AppUser(
      userId: uid,
      email: email.trim(),
      name: name.trim(),
      role: role,
    );

    // 4) Save profile data to Firestore
    await _firestore.collection("users").doc(uid).set(user.toMap());

    // 5) Return user object to the caller
    return user;
  }
}
