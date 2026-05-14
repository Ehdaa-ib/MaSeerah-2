import 'package:flutter/material.dart';

import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import 'map_popup_close_button.dart';

/// Popup title row: **balanced** center title, close on the right (recommendation list, etc.).
class MapPopupHeader extends StatelessWidget {
  const MapPopupHeader({
    super.key,
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  static const double _sideSlot = MapDesignTokens.popupHeaderHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MapDesignTokens.popupHeaderHeight,
      child: Row(
        children: [
          const SizedBox(width: _sideSlot),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MapTextStyles.popupTitle,
            ),
          ),
          SizedBox(
            width: _sideSlot,
            child: MapPopupCloseButton(onPressed: onClose),
          ),
        ],
      ),
    );
  }
}

/// Landmark sheet: close on the **left**, optional **trailing** on the right (countdown).
class MapPopupHeaderLeadingClose extends StatelessWidget {
  const MapPopupHeaderLeadingClose({
    super.key,
    required this.title,
    required this.onClose,
    this.trailing,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? trailing;

  static const double _closeSlot = MapDesignTokens.popupHeaderHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MapDesignTokens.popupHeaderHeight,
      child: Row(
        children: [
          SizedBox(
            width: _closeSlot,
            child: MapPopupCloseButton(onPressed: onClose),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MapTextStyles.popupTitle,
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: MapDesignTokens.spaceSm),
            child: trailing ?? const SizedBox(width: _closeSlot),
          ),
        ],
      ),
    );
  }
}
