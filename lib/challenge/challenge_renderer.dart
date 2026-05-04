import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../model/challenge_model.dart';
import '../model/challenge_stage_model.dart';
import '../model/challenge_type.dart';
import 'challenge_styles.dart';
import 'widgets/assemble_challenge_widget.dart';
import 'widgets/elimination_challenge_widget.dart';
import 'widgets/fill_blank_challenge_widget.dart';
import 'widgets/matching_challenge_widget.dart';
import 'widgets/multiple_choice_challenge_widget.dart';
import 'widgets/reorder_challenge_widget.dart';
import 'widgets/unknown_challenge_widget.dart';

/// Renders a parsed [ChallengeModel] (direct or multi-stage).
///
/// TODO: Wire into landmark region flow after content sheet.
/// TODO: Stage progress bar + animations between stages.
/// TODO: Aggregate scoring and write completion to Firestore.
class ChallengeRenderer extends StatefulWidget {
  const ChallengeRenderer({
    super.key,
    required this.challenge,
    this.nextLandmarkDocumentId,
    this.onChallengeResolved,
  });

  final ChallengeModel challenge;

  /// From parent landmark document (e.g. `nextLandmarkId`), not from `quiz`.
  final String? nextLandmarkDocumentId;

  /// Invoked when a stage reports success (e.g. fill-blank correct answer).
  final void Function({
    required bool success,
    String? nextLandmarkDocumentId,
  })? onChallengeResolved;

  @override
  State<ChallengeRenderer> createState() => _ChallengeRendererState();
}

class _ChallengeRendererState extends State<ChallengeRenderer> {
  late int _stageIndex;

  @override
  void initState() {
    super.initState();
    _stageIndex = 0;
  }

  ChallengeStageModel get _stage => widget.challenge.stages[_stageIndex];

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final total = c.stageCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(
                  'Stage ${_stageIndex + 1} of $total',
                  style: ChallengeStyles.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ChallengeStyles.mutedBrown,
                  ),
                ),
                const Spacer(),
                if (_stageIndex > 0)
                  TextButton(
                    onPressed: () => setState(() => _stageIndex -= 1),
                    child: const Text('Back'),
                  ),
                if (_stageIndex < total - 1)
                  TextButton(
                    onPressed: () => setState(() => _stageIndex += 1),
                    child: const Text('Next stage'),
                  ),
              ],
            ),
          ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey<String>('${_stage.index}_${_stage.stageKey ?? 'direct'}'),
            child: _buildForType(_stage),
          ),
        ),
      ],
    );
  }

  Widget _buildForType(ChallengeStageModel stage) {
    switch (stage.type) {
      case ChallengeType.fillBlank:
        return FillBlankChallengeWidget(
          stage: stage,
          nextLandmarkDocumentId: widget.nextLandmarkDocumentId,
          onResolved: widget.onChallengeResolved,
        );
      case ChallengeType.matching:
        return MatchingChallengeWidget(stage: stage);
      case ChallengeType.reorder:
        return ReorderChallengeWidget(stage: stage);
      case ChallengeType.assemble:
        return AssembleChallengeWidget(stage: stage);
      case ChallengeType.multipleChoice:
        return MultipleChoiceChallengeWidget(stage: stage);
      case ChallengeType.elimination:
        return EliminationChallengeWidget(stage: stage);
      case ChallengeType.unknown:
        return UnknownChallengeWidget(stage: stage);
    }
  }
}

/// Optional outer card wrapper for embedding in sheets / routes.
class ChallengeScaffoldCard extends StatelessWidget {
  const ChallengeScaffoldCard({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.beige,
      elevation: 2,
      shape: ChallengeStyles.cardShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title!, style: ChallengeStyles.titleStyle),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
