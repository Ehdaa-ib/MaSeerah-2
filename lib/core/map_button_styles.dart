import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'map_design_tokens.dart';
import 'map_text_styles.dart';

/// Shared [ButtonStyle] factories for map overlays (footer, challenge, recommendations).
abstract final class MapButtonStyles {
  MapButtonStyles._();

  static ButtonStyle primaryFilled({
    bool enabled = true,
    double verticalPadding = 14,
    double horizontalPadding = 18,
    TextStyle? textStyle,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: MapDesignTokens.primaryAccent,
      foregroundColor: Colors.white,
      disabledBackgroundColor: MapDesignTokens.primaryAccent.withValues(
        alpha: 0.4,
      ),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.88),
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      minimumSize: MapDesignTokens.minimumTouchTarget,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusButton),
      ),
      elevation: enabled ? 2 : 1,
      shadowColor: AppColors.brown.withValues(alpha: 0.35),
      textStyle: textStyle ?? MapTextStyles.buttonLabel,
    );
  }

  /// Brown filled (Show Hint when enabled).
  static ButtonStyle secondaryFilled({
    TextStyle? textStyle,
    double horizontalPadding = 14,
  }) {
    return FilledButton.styleFrom(
      backgroundColor: MapDesignTokens.secondaryAccent,
      foregroundColor: MapDesignTokens.popupBackground,
      padding: EdgeInsets.symmetric(
        vertical: 14,
        horizontal: horizontalPadding,
      ),
      minimumSize: MapDesignTokens.minimumTouchTarget,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusButton),
      ),
      textStyle: textStyle ?? MapTextStyles.buttonLabel,
    );
  }

  static ButtonStyle secondaryOutlined({
    bool enabled = true,
    TextStyle? textStyle,
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: enabled
          ? MapDesignTokens.secondaryAccent
          : MapDesignTokens.secondaryAccent.withValues(alpha: 0.55),
      side: BorderSide(
        color: MapDesignTokens.secondaryAccent.withValues(
          alpha: enabled ? 0.45 : 0.25,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      minimumSize: MapDesignTokens.minimumTouchTarget,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusButton),
      ),
      textStyle: textStyle ?? MapTextStyles.buttonLabel,
    );
  }

  /// Disabled hint button.
  static ButtonStyle hintDisabledOutlined({
    TextStyle? textStyle,
    double horizontalPadding = 14,
  }) {
    return OutlinedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        vertical: 14,
        horizontal: horizontalPadding,
      ),
      minimumSize: MapDesignTokens.minimumTouchTarget,
      tapTargetSize: MaterialTapTargetSize.padded,
      side: BorderSide(
        color: MapDesignTokens.secondaryAccent.withValues(alpha: 0.25),
      ),
      foregroundColor: MapDesignTokens.secondaryAccent.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusButton),
      ),
      textStyle: textStyle ?? MapTextStyles.buttonLabel,
    );
  }

  static const ButtonStyle _challengeFooterLabelAlignment = ButtonStyle(
    alignment: Alignment.center,
  );

  /// Hint + check row on the challenge overlay: centered, single-line labels.
  static ButtonStyle challengeFooterHintEnabled() {
    return secondaryFilled(
      textStyle: MapTextStyles.buttonLabelChallengeFooter,
      horizontalPadding: 8,
    ).merge(_challengeFooterLabelAlignment);
  }

  static ButtonStyle challengeFooterHintDisabled() {
    return hintDisabledOutlined(
      textStyle: MapTextStyles.buttonLabelChallengeFooter,
      horizontalPadding: 8,
    ).merge(_challengeFooterLabelAlignment);
  }

  static ButtonStyle challengeFooterCheck({required bool enabled}) {
    return primaryFilled(
      enabled: enabled,
      verticalPadding: 14,
      horizontalPadding: 8,
      textStyle: MapTextStyles.buttonLabelChallengeFooter,
    ).merge(_challengeFooterLabelAlignment);
  }
}
