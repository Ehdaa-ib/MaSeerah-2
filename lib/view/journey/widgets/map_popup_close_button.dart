import 'package:flutter/material.dart';

import '../../../core/map_design_tokens.dart';

/// Consistent close control for map popups (icon size + color).
class MapPopupCloseButton extends StatelessWidget {
  const MapPopupCloseButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Close',
    this.alignment = Alignment.center,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: MapDesignTokens.popupHeaderHeight,
          minHeight: MapDesignTokens.popupHeaderHeight,
        ),
        onPressed: onPressed,
        icon: Icon(
          Icons.close_rounded,
          size: MapDesignTokens.iconClose,
          color: MapDesignTokens.closeIconColor(),
        ),
      ),
    );
  }
}
