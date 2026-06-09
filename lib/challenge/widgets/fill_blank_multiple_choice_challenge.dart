import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

class FillBlankMultipleChoiceChallenge extends StatelessWidget {
  const FillBlankMultipleChoiceChallenge({
    super.key,
    required this.stage,
    required this.selected,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final String? selected;
  final ValueChanged<String> onChanged;

  String _renderSentence() {
    final q = stage.question ?? '';
    if (q.contains('{{')) return q.replaceAll(RegExp(r'\{\{.*?\}\}'), '_____');
    if (RegExp(r'_{2,}').hasMatch(q)) return q;
    return q.isEmpty ? 'Fill the blank:' : '$q _____';
  }

  @override
  Widget build(BuildContext context) {
    final sentence = _renderSentence();
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
            _SentenceWithBlank(sentence: sentence, filled: selected),
            const SizedBox(height: 14),
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
                style: ChallengeStyles.bodyStyle.copyWith(
                  color: ChallengeStyles.mutedBrown,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SentenceWithBlank extends StatelessWidget {
  const _SentenceWithBlank({required this.sentence, required this.filled});

  final String sentence;
  final String? filled;

  @override
  Widget build(BuildContext context) {
    final parts = sentence.split(RegExp(r'_{2,}'));
    if (parts.length < 2) {
      return Text(sentence, style: ChallengeStyles.titleStyle);
    }
    final before = parts.first;
    final after = parts.sublist(1).join('_____');
    return RichText(
      text: TextSpan(
        style: ChallengeStyles.titleStyle.copyWith(height: 1.35),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.orange.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                (filled == null || filled!.trim().isEmpty) ? '_____ ' : filled!,
                style: ChallengeStyles.bodyStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brown,
                ),
              ),
            ),
          ),
          TextSpan(text: after),
        ],
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
    final border = selected
        ? AppColors.orange
        : AppColors.brown.withValues(alpha: 0.18);
    final fill = selected
        ? AppColors.orange.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.65);
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
