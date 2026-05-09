import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

class ArrangeSentenceAlternativeChallenge extends StatelessWidget {
  const ArrangeSentenceAlternativeChallenge({
    super.key,
    required this.stage,
    required this.selectedTokens,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final List<String> selectedTokens;
  final ValueChanged<List<String>> onChanged;

  List<String> _baseTokens() {
    // Prefer explicit token list, else derive from correct order.
    final t = stage.parts.isNotEmpty ? stage.parts : stage.correctOrder;
    return t.where((e) => e.trim().isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _baseTokens();
    final picked = List<String>.from(selectedTokens);
    final remaining = <String>[...tokens];
    for (final p in picked) {
      remaining.remove(p);
    }

    void reset() => onChanged(const []);

    if (kDebugMode) {
      debugPrint(
        '[ArrangeSentence] stage=${stage.index} tokens=${tokens.length} '
        'picked=$picked remaining=${remaining.length} expectedOrder=${stage.correctOrder.length}',
      );
    }

    final expectedLen = stage.correctOrder.isNotEmpty ? stage.correctOrder.length : tokens.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: ChallengeStyles.cardPadding,
        decoration: ChallengeStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(stage.question ?? 'Arrange the sentence', style: ChallengeStyles.titleStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Your answer', style: ChallengeStyles.bodyStyle.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: picked.isEmpty ? null : reset,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brown,
                    textStyle: ChallengeStyles.bodyStyle.copyWith(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.brown.withValues(alpha: 0.14)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (picked.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Tap words below to build the sentence.',
                          style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
                        ),
                      ),
                    for (final w in picked)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 140),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeOutCubic,
                        child: _WordChip(
                          key: ValueKey('picked:$w:${picked.indexOf(w)}'),
                          text: w,
                          selected: true,
                          onTap: () {
                            final next = List<String>.from(picked);
                            next.remove(w);
                            if (kDebugMode) debugPrint('[ArrangeSentence] removed="$w" next=$next');
                            onChanged(next);
                          },
                        ),
                      ),
                    // Subtle empty slots to match Duolingo-style "placeholders".
                    for (var i = picked.length; i < expectedLen; i++)
                      _SlotChip(key: ValueKey('slot:$i')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('Word bank', style: ChallengeStyles.bodyStyle.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final w in remaining)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: _WordChip(
                      key: ValueKey('bank:$w:${remaining.indexOf(w)}'),
                      text: w,
                      selected: false,
                      onTap: () {
                        final next = List<String>.from(picked)..add(w);
                        if (kDebugMode) debugPrint('[ArrangeSentence] picked="$w" next=$next');
                        onChanged(next);
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    super.key,
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
    final fill = selected ? AppColors.orange.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.72);
    return Material(
      color: fill,
      elevation: selected ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Text(
            text,
            style: ChallengeStyles.bodyStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brown,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.10)),
      ),
      child: Text(
        '     ',
        style: ChallengeStyles.bodyStyle.copyWith(color: Colors.transparent),
      ),
    );
  }
}

