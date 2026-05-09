import 'package:flutter/material.dart';

import '../../../core/map_button_styles.dart';

class MapPrimaryButton extends StatelessWidget {
  const MapPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconSize = 22,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: MapButtonStyles.primaryFilled(enabled: enabled),
        icon: Icon(icon, size: iconSize, color: Colors.white),
        label: Text(label),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: MapButtonStyles.primaryFilled(enabled: enabled),
      child: Text(label),
    );
  }
}
