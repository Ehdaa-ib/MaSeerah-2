import '../model/journey.dart';

/// Abstraction for fetching journey data (e.g. for order creation).
abstract class JourneyRepository {
  /// Returns the journey if it exists, otherwise null.
  Future<Journey?> getById(String journeyId);

  /// Returns all journeys from Firestore.
  Future<List<Journey>> getAll();

  /// Creates a journey document with [journeyId] as the document ID.
  Future<void> create({required String journeyId, required Journey journey});

  /// Updates journey document fields (merge).
  Future<void> update({required String journeyId, required Journey journey});
}
