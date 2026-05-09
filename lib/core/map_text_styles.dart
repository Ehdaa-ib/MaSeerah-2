import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'map_design_tokens.dart';

/// Typography for the Journey Map page: popups, sheets, recommendations, and challenge chrome.
///
/// **All popup header titles** must use [popupTitle] (same size, weight, color, line height).
abstract final class MapTextStyles {
  MapTextStyles._();

  /// Centered (or start) title in popup chrome: landmark sheet, recommendation list, etc.
  static const TextStyle popupTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.2,
    color: MapDesignTokens.titleColor,
  );

  /// Primary names in compact cards (quick recommendation) — same spec as [popupTitle].
  static const TextStyle popupTitleMultiline = popupTitle;

  /// In-card challenge / content prompts: aligns with [popupTitle] weight & size; line height for paragraphs.
  static const TextStyle challengePrompt = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.35,
    color: MapDesignTokens.titleColor,
  );

  /// Body copy on beige (landmark description, recommendation detail).
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: MapDesignTokens.bodyColor,
  );

  static const TextStyle bodyBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.45,
    color: MapDesignTokens.bodyColor,
  );

  /// Landmark sheet rich description (`**bold**`, quotes); slightly larger for comfortable reading.
  static final TextStyle bodyReading = body.copyWith(fontSize: 17, height: 1.62);
  static final TextStyle bodyReadingBold = bodyBold.copyWith(fontSize: 17, height: 1.62);

  /// Slightly smaller body (list secondary lines, hints).
  static const TextStyle bodySmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: MapDesignTokens.bodyColor,
  );

  /// Captions, meta, countdown chips.
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: MapDesignTokens.mutedColor,
  );

  static const TextStyle captionBold = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.35,
    color: MapDesignTokens.mutedColor,
  );

  /// Section labels inside scroll content (e.g. “Price ranges”).
  static const TextStyle sectionHeading = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.25,
    color: MapDesignTokens.titleColor,
  );

  /// Map AppBar journey title.
  static const TextStyle appBarTitle = TextStyle(
    color: AppColors.brown,
    fontWeight: FontWeight.bold,
    fontSize: 18,
    height: 1.2,
  );

  /// Footer landmark name above primary CTA.
  static const TextStyle footerPlaceName = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: MapDesignTokens.bodyColor,
    height: 1.25,
  );

  /// Primary / filled button label (Open in Maps, Check answer, etc.).
  static const TextStyle buttonLabel = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 16,
    height: 1.2,
  );

  /// Challenge overlay footer (Show Hint / Check Your Answer) — compact single-line labels.
  static const TextStyle buttonLabelChallengeFooter = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14,
    height: 1.1,
  );

  static const TextStyle buttonLabelDense = TextStyle(
    fontWeight: FontWeight.w800,
    fontSize: 15,
    height: 1.2,
  );

  /// Italic quoted segments in landmark rich text.
  static const TextStyle quotedInline = TextStyle(
    fontSize: 17,
    height: 1.62,
    color: MapDesignTokens.mutedColor,
    fontStyle: FontStyle.italic,
    fontWeight: FontWeight.w500,
  );
}
