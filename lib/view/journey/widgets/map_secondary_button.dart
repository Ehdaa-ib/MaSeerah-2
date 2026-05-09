import 'package:flutter/material.dart';

import '../../../core/map_button_styles.dart';

class MapSecondaryButton extends StatelessWidget {
  const MapSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: MapButtonStyles.secondaryOutlined(enabled: onPressed != null),
      child: Text(label),
    );
  }
}
