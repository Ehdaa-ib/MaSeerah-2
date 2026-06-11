import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';
import '../challenge_validation.dart';
import 'challenge_hint_section.dart';

/// Placeholder: same interaction as reorder for now; CMS may later distinguish copy.
///
/// TODO: Assemble-specific UI (slots, snapping); landmark integration.
class AssembleChallengeWidget extends StatefulWidget {
  const AssembleChallengeWidget({super.key, required this.stage});

  final ChallengeStageModel stage;

  @override
  State<AssembleChallengeWidget> createState() =>
      _AssembleChallengeWidgetState();
}

class _AssembleChallengeWidgetState extends State<AssembleChallengeWidget> {
  late List<String> _order;
  late List<Key> _rowKeys;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    final parts = widget.stage.parts;
    _order = parts.isNotEmpty
        ? List<String>.from(parts)
        : List<String>.from(widget.stage.options);
    _rowKeys = List<Key>.generate(
      _order.length,
      (i) => ValueKey<Object>('assemble_${widget.stage.index}_$i'),
    );
  }

  void _check() {
    final expected = widget.stage.correctOrder;
    final ok =
        expected.isNotEmpty &&
        ChallengeValidation.validateListOrderAnswer(
          userOrder: _order,
          expectedOrder: expected,
        );
    debugPrint('[Assemble] correct=$ok user=$_order expected=$expected');
    setState(
      () => _feedback = ok ? 'Correct (placeholder)' : 'Not quite — try again.',
    );
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
          Text('Assemble', style: ChallengeStyles.titleStyle),
          if (widget.stage.question != null) ...[
            const SizedBox(height: 10),
            Text(widget.stage.question!, style: ChallengeStyles.bodyStyle),
          ],
          const SizedBox(height: 12),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            onReorder: (oldI, newI) {
              setState(() {
                if (newI > oldI) newI -= 1;
                final item = _order.removeAt(oldI);
                final ky = _rowKeys.removeAt(oldI);
                _order.insert(newI, item);
                _rowKeys.insert(newI, ky);
                _feedback = null;
              });
            },
            children: [
              for (var i = 0; i < _order.length; i++)
                ListTile(
                  key: _rowKeys[i],
                  tileColor: Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(_order[i], style: ChallengeStyles.bodyStyle),
                  trailing: const Icon(Icons.drag_handle),
                ),
            ],
          ),
          ChallengeHintSection(hints: widget.stage.hints),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _order.isEmpty ? null : _check,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Check assembly'),
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
