/// Maps catalog journey ids (`journeys/{id}`) to `journey_landmarks.journeyId` when not stored explicitly.
String? inferLandmarksJourneyIdFromCatalogId(String catalogJourneyId) {
  final t = catalogJourneyId.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^journey_(\d+)$').firstMatch(t);
  if (m != null) return 'journey${m.group(1)}';
  final m2 = RegExp(r'^journey(\d+)$').firstMatch(t);
  if (m2 != null) return 'journey${m2.group(1)}';
  return null;
}
