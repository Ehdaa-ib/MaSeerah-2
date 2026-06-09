import '../model/journey.dart';

/// Whether a catalog journey is playable (vs Coming Soon).
class JourneyAvailability {
  JourneyAvailability._();

  static bool isPlayable({Journey? journey, required String journeyId}) {
    if (journey != null) return journey.isAvailable;
    return _defaultForCatalogId(journeyId);
  }

  static bool _defaultForCatalogId(String journeyId) {
    final normalized = journeyId.trim().toLowerCase().replaceAll('_', '');
    if (normalized == 'journey1') return true;
    if (normalized == 'journey2' || normalized == 'journey3') return false;
    return true;
  }
}
