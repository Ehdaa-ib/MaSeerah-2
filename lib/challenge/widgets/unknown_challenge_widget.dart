import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.challengeUnknownTitle, style: ChallengeStyles.titleStyle),
          const SizedBox(height: 8),
          Text(
            l10n.challengeUnknownBody(stage.type.name),
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
