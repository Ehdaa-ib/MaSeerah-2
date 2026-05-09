import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

/// Fill-in-the-blank where the learner picks one of several options
/// ([ChallengeType.fillBlankWithChoices] / [ChallengeType.fillBlank] with options).
///
/// Layout is scoped to this widget only; other challenge UIs are unchanged.
class FillBlankWithChoicesChallenge extends StatelessWidget {
  const FillBlankWithChoicesChallenge({
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
    final options = stage.options;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        if (!h.isFinite) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _cardBody(
              sentence: sentence,
              options: options,
              scrollableOptions: false,
            ),
          );
        }
        return SizedBox(
          width: double.infinity,
          height: h,
          child: _cardBody(
            sentence: sentence,
            options: options,
            scrollableOptions: true,
          ),
        );
      },
    );
  }

  Widget _cardBody({
    required String sentence,
    required List<String> options,
    required bool scrollableOptions,
  }) {
    final optionsBlock = scrollableOptions
        ? Expanded(
            child: LayoutBuilder(
              builder: (context, inner) {
                if (options.isEmpty) {
                  return Center(
                    child: Text(
                      'No choices in this challenge.',
                      textAlign: TextAlign.center,
                      style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
                    ),
                  );
                }
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: inner.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < options.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _WideOptionPill(
                            text: options[i],
                            selected: selected == options[i],
                            onTap: () => onChanged(options[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No choices in this challenge.',
                    textAlign: TextAlign.center,
                    style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
                  ),
                )
              else
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _WideOptionPill(
                    text: options[i],
                    selected: selected == options[i],
                    onTap: () => onChanged(options[i]),
                  ),
                ],
            ],
          );

    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SentenceWithBlank(sentence: sentence, filled: selected),
          const SizedBox(height: 20),
          optionsBlock,
        ],
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
    final hasFill = filled != null && filled!.trim().isNotEmpty;
    return RichText(
      text: TextSpan(
        style: ChallengeStyles.titleStyle.copyWith(height: 1.4),
        children: [
          TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: hasFill ? 0.14 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasFill ? AppColors.orange : AppColors.orange.withValues(alpha: 0.55),
                    width: hasFill ? 2 : 1.25,
                  ),
                ),
                child: hasFill
                    ? Text(
                        filled!.trim(),
                        style: ChallengeStyles.bodyStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brown,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '― ― ―',
                            style: ChallengeStyles.bodyStyle.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: ChallengeStyles.mutedBrown.withValues(alpha: 0.65),
                              height: 1,
                            ),
                          ),
                        ],
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

class _WideOptionPill extends StatelessWidget {
  const _WideOptionPill({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.orange : AppColors.brown.withValues(alpha: 0.22);
    final fill = selected ? AppColors.orange.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.72);
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: selected ? 2.25 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: ChallengeStyles.bodyStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: AppColors.orange, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
