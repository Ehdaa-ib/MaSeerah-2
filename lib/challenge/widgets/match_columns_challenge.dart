import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

/// Portrait-first matching UI **without connector lines**.
///
/// Interaction:
/// - Tap a top (prompt) card to select it.
/// - Tap a bottom (answer) card to assign it to the selected prompt.
/// - The chosen answer is shown **inside** the prompt card.
/// - Tap the clear (X) on a prompt to remove its match.
/// - Tap a used bottom card (with no prompt selected) to unmatch that pair.
///
/// Emits `leftText -> rightText` via [onChanged] for Firestore-driven validation.
class MatchColumnsChallenge extends StatefulWidget {
  const MatchColumnsChallenge({
    super.key,
    required this.stage,
    required this.selectedMatches,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final Map<String, String> selectedMatches;
  final ValueChanged<Map<String, String>> onChanged;

  @override
  State<MatchColumnsChallenge> createState() => _MatchColumnsChallengeState();
}

class _MatchColumnsChallengeState extends State<MatchColumnsChallenge> {
  String? _selectedTop;
  late List<String> _topShuffled;
  late List<String> _bottomShuffled;

  List<String> get _topItems {
    final pairs = widget.stage.matchingPairs;
    return widget.stage.parts.isNotEmpty ? widget.stage.parts : <String>[for (final p in pairs) p.left];
  }

  List<String> get _bottomItems {
    final pairs = widget.stage.matchingPairs;
    return widget.stage.options.isNotEmpty ? widget.stage.options : {for (final p in pairs) p.right}.toList();
  }

  @override
  void initState() {
    super.initState();
    _reshuffle();
  }

  @override
  void didUpdateWidget(covariant MatchColumnsChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = '${oldWidget.stage.stageKey ?? ''}:${oldWidget.stage.index}';
    final newKey = '${widget.stage.stageKey ?? ''}:${widget.stage.index}';
    if (oldKey != newKey) {
      _selectedTop = null;
      _reshuffle();
    }
  }

  void _reshuffle() {
    final top = List<String>.from(_topItems);
    final bottom = List<String>.from(_bottomItems);
    final seed = ('${widget.stage.stageKey ?? 'direct'}:${widget.stage.index}').hashCode;
    top.shuffle(Random(seed));
    bottom.shuffle(Random(seed ^ 0x9E3779B9));
    _topShuffled = top;
    _bottomShuffled = bottom;
    if (kDebugMode) {
      debugPrint('[MatchingUI] shuffled top=$_topShuffled bottom=$_bottomShuffled');
    }
  }

  void _connect(String top, String bottom) {
    final next = Map<String, String>.from(widget.selectedMatches);

    // One-to-one for bottoms: reassign if already used.
    String? usedBy;
    next.forEach((k, v) {
      if (v == bottom) usedBy = k;
    });
    if (usedBy != null && usedBy != top) {
      next.remove(usedBy);
      if (kDebugMode) debugPrint('[MatchingUI] reassign bottom="$bottom" from top="$usedBy" -> top="$top"');
    }

    next[top] = bottom;
    if (kDebugMode) debugPrint('[MatchingUI] connect top="$top" bottom="$bottom" matches=$next');
    widget.onChanged(next);
  }

  void _disconnectTop(String top) {
    final next = Map<String, String>.from(widget.selectedMatches);
    final removed = next.remove(top);
    if (kDebugMode) debugPrint('[MatchingUI] disconnect top="$top" bottom="${removed ?? ''}"');
    widget.onChanged(next);
  }

  void _disconnectBottom(String bottom) {
    String? topKey;
    widget.selectedMatches.forEach((k, v) {
      if (v == bottom) topKey = k;
    });
    final top = topKey;
    if (top == null) return;
    _disconnectTop(top);
  }

  @override
  Widget build(BuildContext context) {
    final pairs = widget.stage.matchingPairs;
    final top = _topShuffled;
    final bottom = _bottomShuffled;
    final matches = widget.selectedMatches;

    if (pairs.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          width: double.infinity,
          padding: ChallengeStyles.cardPadding,
          decoration: ChallengeStyles.cardDecoration,
          child: Text(
            'Matching data missing in this challenge.',
            style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: ChallengeStyles.cardPadding,
        decoration: ChallengeStyles.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.stage.question ?? 'Match the pairs', style: ChallengeStyles.titleStyle),
            const SizedBox(height: 14),
            Text(
              'Group A',
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brown.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            for (final t in top)
              _PromptCard(
                text: t,
                selected: _selectedTop == t,
                selectedAnswer: matches[t],
                onTap: () {
                  setState(() {
                    if (_selectedTop == t) {
                      _selectedTop = null;
                    } else {
                      _selectedTop = t;
                    }
                  });
                  if (kDebugMode && _selectedTop == t) debugPrint('[MatchingUI] selected top="$t"');
                },
                onClear: matches.containsKey(t) ? () => _disconnectTop(t) : null,
              ),
            const SizedBox(height: 18),
            Container(height: 1, color: AppColors.brown.withValues(alpha: 0.10)),
            const SizedBox(height: 18),
            Text(
              'Group B',
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.brown.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 10),
            for (final b in bottom)
              _AnswerCard(
                text: b,
                used: matches.values.contains(b),
                dimmed: _selectedTop == null && !matches.values.contains(b),
                onTap: () {
                  final selTop = _selectedTop;
                  if (selTop != null) {
                    _connect(selTop, b);
                    setState(() => _selectedTop = null);
                    return;
                  }
                  if (matches.values.contains(b)) {
                    _disconnectBottom(b);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.text,
    required this.selected,
    required this.selectedAnswer,
    required this.onTap,
    required this.onClear,
  });

  final String text;
  final bool selected;
  final String? selectedAnswer;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final has = selectedAnswer != null && selectedAnswer!.trim().isNotEmpty;
    final border = selected ? AppColors.orange : AppColors.brown.withValues(alpha: 0.14);
    final fill = selected ? AppColors.orange.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.62);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  text,
                  style: ChallengeStyles.bodyStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brown,
                  ),
                ),
                if (has) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Selected:',
                        style: ChallengeStyles.bodyStyle.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.brown.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedAnswer!,
                          style: ChallengeStyles.bodyStyle.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (onClear != null)
                        IconButton(
                          onPressed: onClear,
                          icon: Icon(Icons.close_rounded, color: AppColors.brown.withValues(alpha: 0.75)),
                          splashRadius: 18,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.text,
    required this.used,
    required this.dimmed,
    required this.onTap,
  });

  final String text;
  final bool used;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = used ? AppColors.beige.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.62);
    final border = used ? AppColors.brown.withValues(alpha: 0.10) : AppColors.brown.withValues(alpha: 0.14);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: (used || !dimmed) ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: dimmed ? 0.55 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      style: ChallengeStyles.bodyStyle.copyWith(
                        fontWeight: FontWeight.w800,
                        color: used ? AppColors.brown.withValues(alpha: 0.62) : AppColors.brown,
                      ),
                    ),
                  ),
                  if (used)
                    Icon(Icons.check_circle_rounded, size: 18, color: AppColors.orange.withValues(alpha: 0.85)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
