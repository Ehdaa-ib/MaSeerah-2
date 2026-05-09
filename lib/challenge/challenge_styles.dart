import 'package:flutter/material.dart';

import '../core/map_design_tokens.dart';
import '../core/map_text_styles.dart';

/// Challenge content inside map overlay — uses [MapTextStyles] / [MapDesignTokens] for parity with the map UI.
class ChallengeStyles {
  ChallengeStyles._();

  static Color get readableBrown => MapDesignTokens.bodyColor;
  static Color get mutedBrown => MapDesignTokens.mutedColor;

  static RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
    side: BorderSide(color: MapDesignTokens.borderSubtle(0.12)),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: MapDesignTokens.popupBackground,
    borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
    border: Border.all(color: MapDesignTokens.borderSubtle(0.12)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(18);

  static TextStyle get titleStyle => MapTextStyles.challengePrompt;

  static TextStyle get bodyStyle => MapTextStyles.bodySmall;
}
