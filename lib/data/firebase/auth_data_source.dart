import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../model/app_user.dart';

class AuthDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Signs in with email and password. Checks user exists in Firebase Auth,
  /// then fetches profile from Firestore users/{uid} where uid = FirebaseAuth UID.
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    // 1) Sign in with Firebase Auth
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2) Get FirebaseAuth UID - used to read from Firestore users/{uid}
    final uid = userCredential.user!.uid;

    // 3) Read user document from Firestore using users/{uid} pattern
    final doc = await _firestore.collection("users").doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      await _auth.signOut();
      throw Exception("User profile not found");
    }
    final data = Map<String, dynamic>.from(doc.data()!);
    data['userId'] = doc.id;
    return AppUser.fromMap(data);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Registers: creates Firebase Auth user, then writes to Firestore users/{uid}
  /// Document ID must equal FirebaseAuth UID (users/{uid}), not a random ID.
  /// Required fields only. Optional fields (age, gender, preferredLanguage) are left empty/omitted.
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    // 1) Create user in Firebase Auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // 2) Get FirebaseAuth UID - this will be used as the Firestore document ID
    final uid = userCredential.user!.uid;

    // 3) Save user data to Firestore using users/{uid} pattern
    // Document ID = FirebaseAuth UID (not a random ID)
    await _firestore.collection("users").doc(uid).set({
      'email': email.trim(),
      'name': name.trim(),
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));

    // 4) Create a public index entry (hashed) so reset-password can check existence
    // while signed out without querying private user documents.
    await _firestore.collection('email_index').doc(_emailHash(email)).set({
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));

    // Wait a moment to ensure document is fully written before auth state change triggers read
    await Future.delayed(const Duration(milliseconds: 100));

    return AppUser(
      userId: uid,
      email: email.trim(),
      name: name.trim(),
      role: role,
    );
  }

  String _emailHash(String email) {
    final normalized = email.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }
}
