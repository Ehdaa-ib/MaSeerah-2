import 'package:flutter/material.dart';

import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import 'challenge_hint_section.dart';

/// Fallback when [ChallengeType.unknown] or data is incomplete.
///
/// TODO: Telemetry for unknown shapes; admin tooling.
class UnknownChallengeWidget extends StatelessWidget {
  const UnknownChallengeWidget({super.key, required this.stage});

  final ChallengeStageModel stage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Challenge', style: ChallengeStyles.titleStyle),
          const SizedBox(height: 8),
          Text(
            'This challenge type could not be resolved (${stage.type.name}). '
            'Check Firestore `quiz` / `type` fields.',
            style: ChallengeStyles.bodyStyle.copyWith(fontSize: 13, color: ChallengeStyles.mutedBrown),
          ),
          if (stage.question != null) ...[
            const SizedBox(height: 12),
            Text(stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          ChallengeHintSection(hints: stage.hints),
        ],
      ),
    );
  }
}
