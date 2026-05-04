import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Visual baseline aligned with landmark / journey sheets (beige + terracotta).
///
/// TODO: Theme from [ThemeData] extension when challenges are fully integrated.
class ChallengeStyles {
  ChallengeStyles._();

  static const Color readableBrown = Color(0xFF4A2F2A);
  static const Color mutedBrown = Color(0xFF6B4A3F);

  static RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(color: AppColors.brown.withValues(alpha: 0.12)),
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: AppColors.beige,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.brown.withValues(alpha: 0.12)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(18);

  static TextStyle titleStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: readableBrown,
    height: 1.25,
  );

  static TextStyle bodyStyle = const TextStyle(
    fontSize: 15,
    height: 1.45,
    color: readableBrown,
  );
}
