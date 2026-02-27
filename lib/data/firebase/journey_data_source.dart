import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/journey.dart';

/// Firestore access for journeys collection.
class JourneyDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'journeys';

  /// Fetches a journey by document ID. Returns null if not found.
  Future<Journey?> getById(String journeyId) async {
    final doc = await _firestore.collection(_collection).doc(journeyId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    return Journey.fromMap(data, id: doc.id);
  }

  /// Fetches all journeys. Returns empty list if none.
  Future<List<Journey>> getAll() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      return Journey.fromMap(data, id: doc.id);
    }).toList();
  }
}
