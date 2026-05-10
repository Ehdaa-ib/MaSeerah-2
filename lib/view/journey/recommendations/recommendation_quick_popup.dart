import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/map_button_styles.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import '../../../model/recommendation_place.dart';
import '../widgets/map_popup_close_button.dart';

/// FR-21: compact floating card (auto-dismiss 10s; close X).
class RecommendationQuickPopup extends StatelessWidget {
  const RecommendationQuickPopup({
    super.key,
    required this.place,
    required this.onClose,
    required this.onDirections,
    required this.onView,
  });

  final RecommendationPlace place;
  final VoidCallback onClose;
  final VoidCallback onDirections;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          margin: EdgeInsets.zero,
          decoration: MapDesignTokens.quickCardDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MapDesignTokens.radiusPopup),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ThumbStrip(urls: place.imageUrls),
                      const SizedBox(width: MapDesignTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: MapTextStyles.popupTitleMultiline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Distance · ${place.distanceLabel}',
                              style: MapTextStyles.caption.copyWith(
                                color: MapDesignTokens.iconMuted(0.82),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Walk · ${place.walkingLabel}',
                              style: MapTextStyles.caption.copyWith(
                                color: MapDesignTokens.iconMuted(0.82),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (place.rating != null) ...[
                              const SizedBox(height: MapDesignTokens.spaceXs),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: AppColors.orange),
                                  const SizedBox(width: MapDesignTokens.spaceXs),
                                  Text(
                                    place.rating!.toStringAsFixed(1),
                                    style: MapTextStyles.captionBold.copyWith(
                                      color: AppColors.brown,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    ' Google',
                                    style: MapTextStyles.caption.copyWith(
                                      color: MapDesignTokens.iconMuted(0.55),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      MapPopupCloseButton(onPressed: onClose),
                    ],
                  ),
                ),
                Divider(height: 1, color: MapDesignTokens.borderSubtle(0.12)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onDirections,
                          style: MapButtonStyles.secondaryOutlined(),
                          child: const Text('Directions'),
                        ),
                      ),
                      const SizedBox(width: MapDesignTokens.spaceMd),
                      Expanded(
                        child: FilledButton(
                          onPressed: onView,
                          style: MapButtonStyles.primaryFilled(),
                          child: const Text('View'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal thumbnails from [urls]; same dimensions as the legacy single [_Thumb].
class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.urls});

  final List<String> urls;

  static const double _size = 76;
  static const double _maxStripWidth = 220;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return _Thumb(url: null);
    }
    if (urls.length == 1) {
      return _Thumb(url: urls.first);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxStripWidth, maxHeight: _size),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => _Thumb(url: urls[i]),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = _ThumbStrip._size;
    if (url != null && url!.trim().startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusThumb),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(size),
        ),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusThumb),
      ),
      child: Icon(Icons.place, color: MapDesignTokens.iconMuted(0.45)),
    );
  }
}
