import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/map_button_styles.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import '../../../model/recommendation_place.dart';
import '../widgets/map_info_chip.dart';
import '../widgets/map_overlay_sheet_size.dart';
import '../widgets/map_popup_surface.dart';
import 'recommendation_prices_parser.dart';
import 'recommendation_url.dart';

/// Recommendation detail panel; wraps in [Dialog] when [wrapInDialog] is true.
class RecommendationDetailsModal extends StatelessWidget {
  const RecommendationDetailsModal({
    super.key,
    required this.place,
    this.onBack,
    this.wrapInDialog = true,
  });

  final RecommendationPlace place;

  /// When non-null (e.g. list → details flow), shows a back control on the hero.
  final VoidCallback? onBack;

  /// False when embedded in [RecommendationFlowDialog] (outer [Dialog] owns insets).
  final bool wrapInDialog;

  @override
  Widget build(BuildContext context) {
    final gallery = place.imageUrls;
    final priceCategories = place.order == 5
        ? parseRecommendationNestedPrices(place.pricesRaw)
        : const <RecommendationPriceCategory>[];

    final body = MapPopupSurface(
      child: LayoutBuilder(
        builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SafeArea(
                    bottom: false,
                    child: SingleChildScrollView(
                      primary: false,
                      padding: EdgeInsets.zero,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroGallery(
                            urls: gallery,
                            onBack: onBack,
                            onClose: () => Navigator.of(context).pop(),
                          ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                                  child: Text(
                                    place.name,
                                    style: MapTextStyles.popupTitle,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: place.description.trim().isEmpty
                                      ? Text(
                                          'No description yet.',
                                          style: MapTextStyles.body.copyWith(
                                            color: AppColors.brown.withValues(alpha: 0.55),
                                          ),
                                        )
                                      : Text(
                                          place.description.trim(),
                                          style: MapTextStyles.body,
                                        ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final useTwoCol = c.maxWidth > 340;
                                      final gap = 10.0;
                                      final half = (c.maxWidth - gap) / 2;
                                      final fullW = c.maxWidth;

                                      Widget slot(Widget child) => SizedBox(
                                            width: useTwoCol ? half : fullW,
                                            child: child,
                                          );

                                      return Wrap(
                                        spacing: gap,
                                        runSpacing: gap,
                                        children: [
                                          slot(
                                            MapInfoChip(
                                              icon: Icons.payments_outlined,
                                              label: 'Average price',
                                              value: place.averagePrice,
                                            ),
                                          ),
                                          slot(
                                            MapInfoChip(
                                              icon: Icons.directions_walk_outlined,
                                              label: 'Walk time',
                                              value: place.walkingLabel,
                                            ),
                                          ),
                                          slot(
                                            MapInfoChip(
                                              icon: Icons.straighten_outlined,
                                              label: 'Distance from last stop',
                                              value: place.distanceLabel,
                                            ),
                                          ),
                                          if (place.rating != null)
                                            slot(
                                              MapInfoChip(
                                                icon: Icons.star_rounded,
                                                label: 'Rating',
                                                value: place.rating!.toStringAsFixed(1),
                                                iconColor:
                                                    AppColors.orange.withValues(alpha: 0.88),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                if (priceCategories.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    child: Text(
                                      'Price ranges',
                                      style: MapTextStyles.sectionHeading,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    child: Column(
                                      children: [
                                        for (var i = 0; i < priceCategories.length; i++) ...[
                                          if (i > 0) const SizedBox(height: 8),
                                          _PriceCategoryCard(category: priceCategories[i]),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _StickyMapsCta(
                        onOpenMaps: () {
                          launchRecommendationLocationUrl(
                            context,
                            place.locationUrl,
                          );
                        },
                      ),
                    ],
                  );
        },
      ),
    );

    if (wrapInDialog) {
      return Dialog(
        alignment: Alignment.topCenter,
        insetPadding: MapOverlaySheetSize.dialogInset(context),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: MapOverlaySheetSize.constraints(context),
          child: body,
        ),
      );
    }

    return SizedBox.expand(child: body);
  }

}

class _PriceCategoryCard extends StatelessWidget {
  const _PriceCategoryCard({required this.category});

  final RecommendationPriceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MapDesignTokens.cardHighlightGreen(0.18),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusChip),
        border: Border.all(color: MapDesignTokens.borderSubtle(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: Icon(
              category.icon,
              size: MapDesignTokens.iconSmall,
              color: MapDesignTokens.iconMuted(0.72),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: MapTextStyles.bodySmall.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.rangeText,
                  style: MapTextStyles.caption.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: MapDesignTokens.bodyColor,
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

class _HeroGallery extends StatefulWidget {
  const _HeroGallery({
    required this.urls,
    this.onBack,
    required this.onClose,
  });

  final List<String> urls;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  State<_HeroGallery> createState() => _HeroGalleryState();
}

class _HeroGalleryState extends State<_HeroGallery> {
  static const double _height = 200;

  late final PageController _pageController;
  int _pageIndex = 0;

  List<String> get urls => widget.urls;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.green.withValues(alpha: 0.55),
            AppColors.beige,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: MapDesignTokens.iconHero,
          color: MapDesignTokens.iconMuted(0.35),
        ),
      ),
    );
  }

  Widget _networkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: _height,
      errorBuilder: (context, error, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[RecommendationImage.network] LOAD FAILED doc=hero '
            'url=${url.length > 160 ? "${url.substring(0, 160)}…" : url} '
            'error=$error',
          );
        }
        return _placeholder();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: _height,
          width: double.infinity,
          child: urls.isEmpty
              ? _placeholder()
              : urls.length == 1
                  ? _networkImage(urls.first)
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: urls.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (_, i) => _networkImage(urls[i]),
                    ),
        ),
        if (widget.onBack != null)
          Positioned(
            top: 8,
            left: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: widget.onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: MapDesignTokens.iconClose - 4,
                  color: MapDesignTokens.iconMuted(0.85),
                ),
              ),
            ),
          ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            elevation: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: widget.onClose,
              icon: Icon(
                Icons.close_rounded,
                size: MapDesignTokens.iconClose,
                color: MapDesignTokens.iconMuted(0.85),
              ),
            ),
          ),
        ),
        if (urls.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(urls.length, (i) {
                final active = i == _pageIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: active ? 8 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _StickyMapsCta extends StatelessWidget {
  const _StickyMapsCta({required this.onOpenMaps});

  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MapDesignTokens.popupBackground,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: MapDesignTokens.borderSubtle(0.12)),
          SafeArea(
            top: false,
            minimum: MapDesignTokens.paddingStickyCta,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenMaps,
                icon: Icon(Icons.map_outlined, size: MapDesignTokens.iconStandard),
                label: const Text('Open in Google Maps'),
                style: MapButtonStyles.primaryFilled(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
