import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import '../challenge_validation.dart';
import 'challenge_hint_section.dart';

/// Placeholder: tap options to eliminate until the set matches [answer] list semantics.
///
/// TODO: Drag-out animation; per-landmark elimination rules.
class EliminationChallengeWidget extends StatefulWidget {
  const EliminationChallengeWidget({super.key, required this.stage});

  final ChallengeStageModel stage;

  @override
  State<EliminationChallengeWidget> createState() =>
      _EliminationChallengeWidgetState();
}

class _EliminationChallengeWidgetState
    extends State<EliminationChallengeWidget> {
  late List<String> _remaining;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _remaining = List<String>.from(widget.stage.options);
  }

  void _eliminate(String item) {
    setState(() {
      _remaining.remove(item);
      _feedback = null;
    });
  }

  void _check() {
    final ok = ChallengeValidation.validateEliminationAnswer(
      remaining: _remaining,
      expected: widget.stage.answer,
    );
    debugPrint('[Elimination] correct=$ok remaining=$_remaining');
    setState(
      () => _feedback = ok ? 'Correct (placeholder)' : 'Not quite — try again.',
    );
  }

  void _reset() {
    setState(() {
      _remaining = List<String>.from(widget.stage.options);
      _feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Elimination', style: ChallengeStyles.titleStyle),
          if (widget.stage.question != null) ...[
            const SizedBox(height: 10),
            Text(widget.stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          const SizedBox(height: 8),
          Text(
            'Tap an item to remove it from the list.',
            style: ChallengeStyles.bodyStyle.copyWith(
              fontSize: 13,
              color: ChallengeStyles.mutedBrown,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _remaining)
                ActionChip(
                  label: Text(o),
                  onPressed: () => _eliminate(o),
                  backgroundColor: Colors.white.withValues(alpha: 0.7),
                ),
            ],
          ),
          ChallengeHintSection(hints: widget.stage.hints),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _check,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Check'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _reset, child: const Text('Reset')),
            ],
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedback!,
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: _feedback!.startsWith('Correct')
                    ? const Color(0xFF2E7D32)
                    : AppColors.brown,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
