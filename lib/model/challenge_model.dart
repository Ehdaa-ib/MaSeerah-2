import 'challenge_stage_model.dart';

/// Parsed `quiz` from a landmark: either one direct payload or multiple `stageN` entries.
class ChallengeModel {
  ChallengeModel({
    required this.isStaged,
    required this.stages,
    this.landmarkDocumentId,
    this.rawQuiz = const {},
  });

  /// True when `quiz` contained `stage1`, `stage2`, … keys.
  final bool isStaged;

  /// Non-empty. Direct quizzes are represented as a single stage.
  final List<ChallengeStageModel> stages;

  /// Optional context for logging / future persistence.
  final String? landmarkDocumentId;

  /// Original `quiz` map (when it was a [Map]) for debugging / future features.
  final Map<String, dynamic> rawQuiz;

  int get stageCount => stages.length;
}
