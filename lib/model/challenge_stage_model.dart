import 'challenge_matching_pair.dart';
import 'challenge_type.dart';

/// One logical step: either the whole `quiz` map (direct) or `quiz.stageN` (staged).
class ChallengeStageModel {
  ChallengeStageModel({
    required this.index,
    this.stageKey,
    required this.type,
    this.question,
    this.options = const [],
    this.hints = const [],
    this.parts = const [],
    this.correctOrder = const [],
    this.answer,
    this.matchingPairs = const [],
    this.resultMessage,
    this.raw = const {},
  });

  /// 0-based order in the challenge flow.
  final int index;

  /// Firestore key when staged, e.g. `stage1`. Null for a single direct `quiz` object.
  final String? stageKey;

  final ChallengeType type;

  final String? question;

  final List<String> options;

  final List<String> hints;

  final List<String> parts;

  final List<String> correctOrder;

  /// May be [String], [List], or [Map] depending on challenge type / CMS data.
  final Object? answer;

  final List<ChallengeMatchingPair> matchingPairs;

  final String? resultMessage;

  /// Unparsed subset for forward compatibility.
  final Map<String, dynamic> raw;
}
