import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Shared layout, color, and elevation tokens for the Journey Map page and its overlays.
///
/// Prefer these over ad-hoc literals in map popups, recommendations, landmark sheet, and
/// challenge chrome (buttons, hints) so the screen reads as one system.
abstract final class MapDesignTokens {
  MapDesignTokens._();

  // --- Semantic colors (single accent: [AppColors.orange]) ---
  static const Color primaryAccent = AppColors.orange;
  static const Color secondaryAccent = AppColors.brown;
  static const Color popupBackground = AppColors.beige;
  static const Color titleColor = AppColors.brown;
  static const Color bodyColor = Color(0xFF4A2F2A);
  static const Color mutedColor = Color(0xFF6B4A3F);
  static const Color successColor = Color(0xFF2E7D32);
  static Color scrimOverMap() => Colors.black.withValues(alpha: 0.35);

  static Color borderSubtle([double a = 0.12]) =>
      AppColors.brown.withValues(alpha: a);
  static Color borderMedium([double a = 0.2]) =>
      AppColors.brown.withValues(alpha: a);
  static Color iconMuted([double a = 0.72]) =>
      AppColors.brown.withValues(alpha: a);
  static Color closeIconColor([double a = 0.72]) =>
      AppColors.brown.withValues(alpha: a);

  static Color cardOnBeige([double alpha = 0.72]) =>
      Colors.white.withValues(alpha: alpha);
  static Color cardHighlightGreen([double alpha = 0.18]) =>
      AppColors.green.withValues(alpha: alpha);

  // --- Radii ---
  static const double radiusPopup = 20;
  static const double radiusCard = 16;
  static const double radiusChip = 14;
  static const double radiusButton = 14;
  static const double radiusThumb = 12;

  // --- Spacing scale ---
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;

  /// Outer margin for centered map sheets (matches challenge / recommendation overlays).
  static const EdgeInsets sheetOuterMargin = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static const EdgeInsets paddingPopupContent = EdgeInsets.symmetric(
    horizontal: 18,
  );
  static const EdgeInsets paddingFooter = EdgeInsets.fromLTRB(20, 14, 20, 16);
  static const EdgeInsets paddingLandmarkScroll = EdgeInsets.fromLTRB(
    22,
    18,
    22,
    12,
  );
  static const EdgeInsets paddingStickyCta = EdgeInsets.fromLTRB(
    16,
    10,
    16,
    12,
  );

  /// Minimum comfortable tap target (accessibility).
  static const Size minimumTouchTarget = Size(64, 48);

  static const EdgeInsets paddingButtonVertical = EdgeInsets.symmetric(
    vertical: 14,
    horizontal: 18,
  );

  static const EdgeInsets paddingButtonVerticalDense = EdgeInsets.symmetric(
    vertical: 14,
    horizontal: 14,
  );

  // --- Popup header (shared title bar) ---
  static const double popupHeaderHeight = 48;
  static const double popupTitleHorizontalInset = 48;

  // --- Icons ---
  static const double iconClose = 22;
  static const double iconStandard = 22;
  static const double iconSmall = 20;
  static const double iconHero = 48;

  // --- Shadows ---
  static List<BoxShadow> shadowPopup = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> shadowLandmarkSheet = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// Challenge / list surface inside a sheet.
  static BoxDecoration sheetInnerDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? popupBackground,
      borderRadius: BorderRadius.circular(radiusPopup),
      border: Border.all(color: borderSubtle(0.12)),
      boxShadow: shadowPopup,
    );
  }

  static BoxDecoration landmarkSheetDecoration() {
    return BoxDecoration(
      color: popupBackground,
      borderRadius: BorderRadius.circular(radiusPopup),
      border: Border.all(color: borderSubtle(0.1)),
      boxShadow: shadowLandmarkSheet,
    );
  }

  static BoxDecoration quickCardDecoration() {
    return BoxDecoration(
      color: popupBackground,
      borderRadius: BorderRadius.circular(radiusPopup),
      boxShadow: shadowSoft,
      border: Border.all(color: borderSubtle(0.14)),
    );
  }
}
