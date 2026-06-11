import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import '../challenge_validation.dart';

/// Fill-in-the-blank challenge driven entirely by [ChallengeStageModel] (Firestore `quiz`).
class FillBlankChallengeWidget extends StatefulWidget {
  const FillBlankChallengeWidget({
    super.key,
    required this.stage,
    this.nextLandmarkDocumentId,
    this.onResolved,
  });

  final ChallengeStageModel stage;

  /// Next landmark document id from the parent landmark (not from `quiz`).
  final String? nextLandmarkDocumentId;

  /// Called when the user submits a correct answer (trim + case-insensitive vs [stage.answer]).
  final void Function({required bool success, String? nextLandmarkDocumentId})?
  onResolved;

  @override
  State<FillBlankChallengeWidget> createState() =>
      _FillBlankChallengeWidgetState();
}

class _FillBlankChallengeWidgetState extends State<FillBlankChallengeWidget> {
  final _controller = TextEditingController();
  String? _feedback;
  bool _lastCorrect = false;
  final Set<int> _revealedHintIndices = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _canRevealHint(int index) {
    if (index < 0 || index >= widget.stage.hints.length) return false;
    if (_revealedHintIndices.contains(index)) return false;
    if (index == 0) return true;
    return _revealedHintIndices.contains(index - 1);
  }

  void _revealHint(int index) {
    if (!_canRevealHint(index)) return;
    setState(() => _revealedHintIndices.add(index));
  }

  void _check() {
    final ok = ChallengeValidation.validateStringAnswer(
      candidate: _controller.text,
      expected: widget.stage.answer,
    );
    debugPrint('[FillBlank] correct=$ok stage=${widget.stage.index}');
    if (ok) {
      widget.onResolved?.call(
        success: true,
        nextLandmarkDocumentId: widget.nextLandmarkDocumentId,
      );
    }
    setState(() {
      _lastCorrect = ok;
      _feedback = ok ? 'Well done! That\'s correct.' : 'Not quite — try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hints = widget.stage.hints;
    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Fill in the blank', style: ChallengeStyles.titleStyle),
          if (widget.stage.question != null) ...[
            const SizedBox(height: 10),
            Text(widget.stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Your answer',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.65),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < hints.length; i++)
                  OutlinedButton(
                    onPressed: _canRevealHint(i) ? () => _revealHint(i) : null,
                    child: Text('Hint ${i + 1}'),
                  ),
              ],
            ),
            for (var i = 0; i < hints.length; i++)
              if (_revealedHintIndices.contains(i)) ...[
                const SizedBox(height: 8),
                Text(
                  hints[i],
                  style: ChallengeStyles.bodyStyle.copyWith(
                    color: ChallengeStyles.mutedBrown,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _check,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Check answer'),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 10),
            Text(
              _feedback!,
              style: ChallengeStyles.bodyStyle.copyWith(
                color: _lastCorrect ? const Color(0xFF2E7D32) : AppColors.brown,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
