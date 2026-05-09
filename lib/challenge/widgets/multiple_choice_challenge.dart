import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

class MultipleChoiceChallenge extends StatelessWidget {
  const MultipleChoiceChallenge({
    super.key,
    required this.stage,
    required this.selected,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final opts = stage.options;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: ChallengeStyles.cardPadding,
        decoration: ChallengeStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stage.question != null)
              Text(stage.question!, style: ChallengeStyles.titleStyle)
            else
              Text('Choose the correct answer', style: ChallengeStyles.titleStyle),
            const SizedBox(height: 12),
            for (final o in opts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChoiceCard(
                  text: o,
                  selected: selected == o,
                  onTap: () => onChanged(o),
                ),
              ),
            if (opts.isEmpty)
              Text(
                'No options in this challenge.',
                style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.orange : AppColors.brown.withValues(alpha: 0.18);
    final fill = selected ? AppColors.orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.65);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Text(
            text,
            style: ChallengeStyles.bodyStyle.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}

