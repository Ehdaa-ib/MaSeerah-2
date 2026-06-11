import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/app_user.dart';

class UserDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'users';

  Future<List<AppUser>> getAll() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['userId'] = doc.id;
      return AppUser.fromMap(data);
    }).toList();
  }

  Future<void> update({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection(_collection)
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }
}
