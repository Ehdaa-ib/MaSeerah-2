import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import '../challenge_validation.dart';
import 'challenge_hint_section.dart';

/// Placeholder for single- or multi-select choice challenges.
///
/// TODO: Landmark flow; image options; accessibility.
class MultipleChoiceChallengeWidget extends StatefulWidget {
  const MultipleChoiceChallengeWidget({super.key, required this.stage});

  final ChallengeStageModel stage;

  @override
  State<MultipleChoiceChallengeWidget> createState() => _MultipleChoiceChallengeWidgetState();
}

class _MultipleChoiceChallengeWidgetState extends State<MultipleChoiceChallengeWidget> {
  String? _selected;
  String? _feedback;

  void _check() {
    if (_selected == null) {
      setState(() => _feedback = 'Pick an option first.');
      return;
    }
    final ok = ChallengeValidation.validateStringAnswer(
      candidate: _selected!,
      expected: widget.stage.answer,
    );
    debugPrint('[MultipleChoice] correct=$ok choice=$_selected');
    setState(() => _feedback = ok ? 'Correct (placeholder)' : 'Not quite — try again.');
  }

  @override
  Widget build(BuildContext context) {
    final opts = widget.stage.options;
    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Multiple choice', style: ChallengeStyles.titleStyle),
          if (widget.stage.question != null) ...[
            const SizedBox(height: 10),
            Text(widget.stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          const SizedBox(height: 12),
          ...opts.map(
            (o) => RadioListTile<String>(
              value: o,
              groupValue: _selected,
              onChanged: (v) => setState(() {
                _selected = v;
                _feedback = null;
              }),
              title: Text(o, style: ChallengeStyles.bodyStyle),
              activeColor: AppColors.orange,
            ),
          ),
          ChallengeHintSection(hints: widget.stage.hints),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: opts.isEmpty ? null : _check,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Check answer'),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedback!,
              style: ChallengeStyles.bodyStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: _feedback!.startsWith('Correct') ? const Color(0xFF2E7D32) : AppColors.brown,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
