/// Types of interactive challenges loaded from Firestore `quiz` payloads.
///
/// TODO: Wire each type to landmark-specific flows and scoring.
enum ChallengeType {
  /// Sentence with a single blank + choices as chips.
  fillBlankWithChoices,

  /// Matching between two columns (mobile-friendly selection UI).
  matchColumns,

  /// Standard vertical event ordering.
  orderEvents,

  /// Polished variant of ordering cards.
  orderEventsStyled,

  /// Word-chip sentence builder (tap tokens into answer area).
  arrangeSentenceAlternative,

  /// Multiple choice question (options as cards).
  multipleChoice,

  /// Sentence with a single blank + options as MCQ-style cards.
  fillBlankWithMultipleChoice,

  /// Multiple complete sentence options; user selects correct.
  arrangeSentenceWithMultipleChoice,

  /// Legacy / fallback types retained for older data.
  fillBlank,
  matching,
  reorder,
  assemble,
  elimination,

  /// Structure could not be classified; UI may show a generic fallback.
  unknown,
}
