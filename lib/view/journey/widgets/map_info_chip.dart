import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';

/// Compact info row used in recommendation details (and anywhere else on the map page).
class MapInfoChip extends StatelessWidget {
  const MapInfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: MapDesignTokens.cardHighlightGreen(0.16),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusChip),
        border: Border.all(color: MapDesignTokens.borderSubtle(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: MapDesignTokens.iconSmall,
            color: iconColor ?? MapDesignTokens.iconMuted(0.78),
          ),
          const SizedBox(width: MapDesignTokens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.captionBold.copyWith(
                    color: AppColors.brown.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: MapTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
