/// Types of interactive challenges loaded from Firestore `quiz` payloads.
///
/// TODO: Wire each type to landmark-specific flows and scoring.
enum ChallengeType {
  fillBlank,
  matching,
  reorder,
  assemble,
  multipleChoice,
  elimination,
  /// Structure could not be classified; UI may show a generic fallback.
  unknown,
}
