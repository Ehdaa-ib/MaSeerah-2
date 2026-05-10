import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import '../../../model/recommendation_place.dart';
import '../widgets/map_popup_header.dart';
import '../widgets/map_popup_surface.dart';

/// Panel used inside [RecommendationFlowDialog] (fills parent). Not a [Dialog] itself.
class RecommendationListPopup extends StatelessWidget {
  const RecommendationListPopup({
    super.key,
    required this.places,
    this.onPickPlace,
  });

  final List<RecommendationPlace> places;

  /// When set (flow mode), opens details in parent. Otherwise uses [Navigator.pop] with result.
  final void Function(RecommendationPlace)? onPickPlace;

  @override
  Widget build(BuildContext context) {
    final sorted = [...places]..sort((a, b) => a.order.compareTo(b.order));

    return MapPopupSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MapPopupHeader(
            title: 'Recommended places',
            onClose: () => Navigator.of(context).pop(),
          ),
          Divider(height: 1, thickness: 1, color: MapDesignTokens.borderSubtle(0.1)),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: MapDesignTokens.iconHero,
                            color: MapDesignTokens.iconMuted(0.35),
                          ),
                          const SizedBox(height: MapDesignTokens.spaceLg),
                          Text(
                            'No recommendations yet',
                            textAlign: TextAlign.center,
                            style: MapTextStyles.popupTitle.copyWith(
                              color: AppColors.brown.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: MapDesignTokens.spaceMd),
                          Text(
                            'Explore more landmarks to unlock nearby places.',
                            textAlign: TextAlign.center,
                            style: MapTextStyles.bodySmall.copyWith(
                              color: MapDesignTokens.iconMuted(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) => const SizedBox(height: MapDesignTokens.spaceSm),
                    itemBuilder: (context, i) {
                      final p = sorted[i];
                      return Material(
                        color: MapDesignTokens.cardHighlightGreen(0.22),
                        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
                          onTap: () {
                            if (onPickPlace != null) {
                              onPickPlace!(p);
                            } else {
                              Navigator.of(context).pop<RecommendationPlace>(p);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            child: Row(
                              children: [
                                _RecommendationListLeadingImages(urls: p.imageUrls),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: MapTextStyles.bodyBold.copyWith(
                                          fontSize: 16,
                                          color: AppColors.brown,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '${p.distanceLabel} · ${p.walkingLabel}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: MapTextStyles.caption.copyWith(
                                          fontSize: 13,
                                          color: MapDesignTokens.bodyColor.withValues(alpha: 0.88),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: MapDesignTokens.iconMuted(0.45),
                                  size: 28,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationListLeadingImages extends StatelessWidget {
  const _RecommendationListLeadingImages({required this.urls});

  final List<String> urls;

  static const double _mainRadius = 22;
  static const double _extraDiameter = 22;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return CircleAvatar(
        radius: _mainRadius,
        backgroundColor: AppColors.green.withValues(alpha: 0.4),
        child: Icon(
          Icons.place_outlined,
          color: MapDesignTokens.iconMuted(0.5),
        ),
      );
    }

    final first = urls.first;
    final hasNetworkFirst = first.startsWith('http');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: _mainRadius,
          backgroundColor: AppColors.green.withValues(alpha: 0.4),
          backgroundImage: hasNetworkFirst ? NetworkImage(first) : null,
          child: !hasNetworkFirst
              ? Icon(
                  Icons.place_outlined,
                  color: MapDesignTokens.iconMuted(0.5),
                )
              : null,
        ),
        if (urls.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: SizedBox(
              height: _mainRadius * 2,
              width: math.min((urls.length - 1) * 26.0, 78),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: urls.length - 1,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, i) {
                  final url = urls[i + 1];
                  if (!url.startsWith('http')) {
                    return SizedBox(
                      width: _extraDiameter,
                      height: _extraDiameter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.place_outlined,
                          size: 12,
                          color: MapDesignTokens.iconMuted(0.45),
                        ),
                      ),
                    );
                  }
                  return ClipOval(
                    child: Image.network(
                      url,
                      width: _extraDiameter,
                      height: _extraDiameter,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => SizedBox(
                        width: _extraDiameter,
                        height: _extraDiameter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.place_outlined,
                            size: 12,
                            color: MapDesignTokens.iconMuted(0.45),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
