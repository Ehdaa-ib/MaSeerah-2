import '../model/journey.dart';

/// Abstraction for fetching journey data (e.g. for order creation).
abstract class JourneyRepository {
  /// Returns the journey if it exists, otherwise null.
  Future<Journey?> getById(String journeyId);
}
