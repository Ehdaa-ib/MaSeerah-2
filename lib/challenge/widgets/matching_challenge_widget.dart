import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import '../challenge_validation.dart';
import 'challenge_hint_section.dart';

/// Placeholder: build user map left → selected right via dropdowns.
///
/// TODO: Drag lines UI; shuffle right column; landmark wiring.
class MatchingChallengeWidget extends StatefulWidget {
  const MatchingChallengeWidget({super.key, required this.stage});

  final ChallengeStageModel stage;

  @override
  State<MatchingChallengeWidget> createState() => _MatchingChallengeWidgetState();
}

class _MatchingChallengeWidgetState extends State<MatchingChallengeWidget> {
  final Map<String, String> _matches = {};
  String? _feedback;
  bool _feedbackPositive = false;

  void _check() {
    final l10n = AppLocalizations.of(context)!;
    final pairs = widget.stage.matchingPairs;
    final ok = pairs.isNotEmpty &&
        ChallengeValidation.validateMatchingAnswer(
          userMatches: _matches,
          expectedPairs: pairs,
        );
    debugPrint('[Matching] correct=$ok matches=$_matches');
    setState(() {
      _feedbackPositive = ok;
      _feedback = ok ? l10n.challengeFeedbackCorrect : l10n.challengeFeedbackTryAgain;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pairs = widget.stage.matchingPairs;
    final rights = <String>[];
    for (final p in pairs) {
      if (!rights.contains(p.right)) rights.add(p.right);
    }

    return Container(
      width: double.infinity,
      padding: ChallengeStyles.cardPadding,
      decoration: ChallengeStyles.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Matching', style: ChallengeStyles.titleStyle),
          if (widget.stage.question != null) ...[
            const SizedBox(height: 10),
            Text(widget.stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          const SizedBox(height: 12),
          if (pairs.isEmpty)
            Text(
              'No matching pairs in data.',
              style: ChallengeStyles.bodyStyle.copyWith(color: ChallengeStyles.mutedBrown),
            )
          else
            for (final p in pairs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(p.left, style: ChallengeStyles.bodyStyle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.65),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        hint: const Text('Match'),
                        value: () {
                          if (!_matches.containsKey(p.left)) return null;
                          final v = _matches[p.left]!;
                          return rights.contains(v) ? v : null;
                        }(),
                        items: [
                          for (final r in rights)
                            DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() {
                            if (v == null) {
                              _matches.remove(p.left);
                            } else {
                              _matches[p.left] = v;
                            }
                            _feedback = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
          ChallengeHintSection(hints: widget.stage.hints),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: pairs.isEmpty ? null : _check,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Check matches'),
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
