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
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.green.withValues(alpha: 0.4),
                                  backgroundImage: p.primaryImageUrl != null &&
                                          p.primaryImageUrl!.startsWith('http')
                                      ? NetworkImage(p.primaryImageUrl!)
                                      : null,
                                  child: p.primaryImageUrl == null ||
                                          !p.primaryImageUrl!.startsWith('http')
                                      ? Icon(
                                          Icons.place_outlined,
                                          color: MapDesignTokens.iconMuted(0.5),
                                        )
                                      : null,
                                ),
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
