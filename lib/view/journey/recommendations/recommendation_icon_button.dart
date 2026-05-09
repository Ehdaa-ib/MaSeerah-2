import 'package:flutter/material.dart';

import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';

/// Map corner control with optional count badge (FR-22).
class RecommendationIconButton extends StatelessWidget {
  const RecommendationIconButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapDesignTokens.popupBackground.withValues(alpha: 0.96),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
        side: BorderSide(color: MapDesignTokens.borderMedium(0.2)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Badge(
            isLabelVisible: count > 0,
            label: Text(
              '$count',
              style: MapTextStyles.caption.copyWith(
                fontSize: 11,
                color: MapDesignTokens.popupBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: MapDesignTokens.primaryAccent,
            child: Icon(
              Icons.recommend_outlined,
              color: MapDesignTokens.secondaryAccent,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
