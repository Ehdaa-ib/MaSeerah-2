import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/app_colors.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import '../../../model/recommendation_place.dart';
import '../../../widgets/app_network_image.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return MapPopupSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MapPopupHeader(
            title: l10n.recommendationListTitle,
            onClose: () => Navigator.of(context).pop(),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: MapDesignTokens.borderSubtle(0.1),
          ),
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
                            l10n.recommendationListEmptyTitle,
                            textAlign: TextAlign.center,
                            style: MapTextStyles.popupTitle.copyWith(
                              color: AppColors.brown.withValues(alpha: 0.88),
                            ),
                          ),
                          const SizedBox(height: MapDesignTokens.spaceMd),
                          Text(
                            l10n.recommendationListEmptySubtitle,
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
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
                    itemCount: sorted.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: MapDesignTokens.spaceSm),
                    itemBuilder: (context, i) {
                      final p = sorted[i];
                      return Material(
                        color: MapDesignTokens.cardHighlightGreen(0.22),
                        borderRadius: BorderRadius.circular(
                          MapDesignTokens.radiusCard,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            MapDesignTokens.radiusCard,
                          ),
                          onTap: () {
                            if (onPickPlace != null) {
                              onPickPlace!(p);
                            } else {
                              Navigator.of(context).pop<RecommendationPlace>(p);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                _RecommendationListPhotoStrip(
                                  urls: p.imageUrls,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          color: MapDesignTokens.bodyColor
                                              .withValues(alpha: 0.88),
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

/// Horizontally scrollable rectangular previews from Firestore `images`.
class _RecommendationListPhotoStrip extends StatelessWidget {
  const _RecommendationListPhotoStrip({required this.urls});

  final List<String> urls;

  static const double _h = 56;
  static const double _stripW = 100;
  static const double _slideW = 72;

  List<String> get _valid =>
      urls.where((u) => u.trim().startsWith('http')).toList();

  @override
  Widget build(BuildContext context) {
    final valid = _valid;
    return SizedBox(
      width: _stripW,
      height: _h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: valid.isEmpty
            ? ColoredBox(
                color: AppColors.green.withValues(alpha: 0.4),
                child: Center(
                  child: Icon(
                    Icons.place_outlined,
                    color: MapDesignTokens.iconMuted(0.5),
                  ),
                ),
              )
            : valid.length == 1
            ? AppNetworkImage(
                url: valid.first,
                fit: BoxFit.cover,
                width: _stripW,
                height: _h,
                memCacheWidth: (_stripW * 2).round(),
                error: ColoredBox(
                  color: AppColors.green.withValues(alpha: 0.4),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: MapDesignTokens.iconMuted(0.5),
                    ),
                  ),
                ),
              )
            : ListView.separated(
                primary: false,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: valid.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (_, i) => SizedBox(
                  width: _slideW,
                  height: _h,
                  child: AppNetworkImage(
                    url: valid[i],
                    fit: BoxFit.cover,
                    width: _slideW,
                    height: _h,
                    memCacheWidth: (_slideW * 2).round(),
                    error: ColoredBox(
                      color: AppColors.green.withValues(alpha: 0.35),
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 22,
                        color: MapDesignTokens.iconMuted(0.45),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
