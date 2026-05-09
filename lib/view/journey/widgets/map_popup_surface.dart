import 'package:flutter/material.dart';

import '../../../core/map_design_tokens.dart';

/// Beige rounded surface used by recommendation list, quick card shell, etc.
class MapPopupSurface extends StatelessWidget {
  const MapPopupSurface({
    super.key,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
    this.elevation = 10,
  });

  final Widget child;
  final Clip clipBehavior;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapDesignTokens.popupBackground,
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(MapDesignTokens.radiusPopup),
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}
