import 'package:flutter/material.dart';

import '../../model/challenge_stage_model.dart';
import 'multiple_choice_challenge.dart';

class ArrangeSentenceMultipleChoiceChallenge extends StatelessWidget {
  const ArrangeSentenceMultipleChoiceChallenge({
    super.key,
    required this.stage,
    required this.selected,
    required this.onChanged,
  });

  final ChallengeStageModel stage;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Render as selecting a complete sentence option (not ordering UI).
    return MultipleChoiceChallenge(
      stage: stage,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

