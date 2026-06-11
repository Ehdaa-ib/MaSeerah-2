import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../challenge_styles.dart';

/// Reusable collapsible-style hint list for all challenge placeholders.
///
/// TODO: Expand/collapse animation; richer typography.
class ChallengeHintSection extends StatelessWidget {
  const ChallengeHintSection({super.key, required this.hints});

  final List<String> hints;

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ChallengeStyles.readableBrown.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.challengeHintsHeading,
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: ChallengeStyles.mutedBrown,
              ),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < hints.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: ChallengeStyles.bodyStyle.copyWith(fontSize: 13),
                    ),
                    Expanded(
                      child: Text(
                        hints[i],
                        style: ChallengeStyles.bodyStyle.copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
