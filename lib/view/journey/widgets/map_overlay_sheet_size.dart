import 'package:flutter/material.dart';

import '../../../core/map_design_tokens.dart';

/// Matches the region landmark sheet on the map: fraction × fraction of the screen.
/// Use for challenge overlay, recommendation dialogs, and other map “page” modals.
class MapOverlaySheetSize {
  MapOverlaySheetSize._();

  /// Slightly wider than before so list rows fill more of the screen; still centered like region/challenge.
  static const double widthFraction = 0.94;
  static const double heightFraction = 0.88;

  /// Same outer margin as the challenge overlay container in [JourneyMapScreen].
  static const EdgeInsets overlayMargin = MapDesignTokens.sheetOuterMargin;

  static BoxConstraints constraints(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return BoxConstraints(
      maxWidth: s.width * widthFraction,
      maxHeight: s.height * heightFraction,
    );
  }

  /// Top of the map **body** (below status bar + [AppBar]), matching where region/challenge sheets sit.
  static double mapContentTopInset(BuildContext context) {
    return MediaQuery.paddingOf(context).top + kToolbarHeight;
  }

  /// [Dialog.insetPadding]: same horizontal/vertical margins as map sheets, with top aligned to **body**
  /// (below the map AppBar), not the raw screen top — so recommendation dialogs line up with challenge/region popups.
  static EdgeInsets dialogInset(BuildContext context) {
    final bodyTop = mapContentTopInset(context);
    return EdgeInsets.fromLTRB(
      overlayMargin.left,
      overlayMargin.top + bodyTop,
      overlayMargin.right,
      overlayMargin.bottom,
    );
  }
}
