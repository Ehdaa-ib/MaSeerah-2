import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import '../challenge_styles.dart';

class OrderEventsChallenge extends StatefulWidget {
  const OrderEventsChallenge({
    super.key,
    required this.stage,
    required this.order,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final List<String>? order;
  final ValueChanged<List<String>> onChanged;

  @override
  State<OrderEventsChallenge> createState() => _OrderEventsChallengeState();
}

class _OrderEventsChallengeState extends State<OrderEventsChallenge> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    final base = widget.stage.parts.isNotEmpty ? widget.stage.parts : widget.stage.correctOrder;
    _items = widget.order ?? _shuffled(base);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onChanged(List<String>.from(_items)));
  }

  @override
  void didUpdateWidget(covariant OrderEventsChallenge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.order != null && widget.order != _items) {
      _items = List<String>.from(widget.order!);
    }
  }

  List<String> _shuffled(List<String> input) {
    final out = List<String>.from(input);
    out.shuffle(Random());
    return out;
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
          Text(widget.stage.question ?? 'Order the events', style: ChallengeStyles.titleStyle),
          const SizedBox(height: 12),
          Expanded(
            child: ReorderableListView(
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
                return AnimatedBuilder(
                  animation: curved,
                  builder: (context, _) {
                    final t = curved.value;
                    final scale = 1.0 + (0.02 * t);
                    return Transform.scale(
                      scale: scale,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 10,
                        shadowColor: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: child,
                        ),
                      ),
                    );
                  },
                );
              },
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
                widget.onChanged(List<String>.from(_items));
              },
              children: [
                for (var i = 0; i < _items.length; i++)
                  ReorderableDelayedDragStartListener(
                    key: ValueKey(_items[i]),
                    index: i,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brown.withValues(alpha: 0.14)),
                      ),
                      child: ListTile(
                        dense: false,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.orange.withValues(alpha: 0.18),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.brown,
                            ),
                          ),
                        ),
                        title: Text(
                          _items[i],
                          style: ChallengeStyles.bodyStyle.copyWith(fontWeight: FontWeight.w700),
                        ),
                        // Visual hint only; dragging works from anywhere on the card.
                        trailing: Icon(Icons.drag_handle_rounded, color: AppColors.brown.withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

