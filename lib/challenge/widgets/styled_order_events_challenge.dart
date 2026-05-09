import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../model/challenge_stage_model.dart';
import 'order_events_challenge.dart';

class StyledOrderEventsChallenge extends StatelessWidget {
  const StyledOrderEventsChallenge({
    super.key,
    required this.stage,
    required this.order,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final List<String>? order;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.orange.withValues(alpha: 0.08),
            AppColors.beige.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: OrderEventsChallenge(
        stage: stage,
        order: order,
        onChanged: onChanged,
      ),
    );
  }
}

