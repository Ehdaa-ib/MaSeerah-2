import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders an SVG journey map where each region is a `<g id="region_N">...</g>`
/// group inside the SVG (N = 1..regionCount).
///
/// - Completed regions: full color
/// - Active region: full color + tappable
/// - Future regions: grayscale + not tappable
///
/// If the SVG does not contain the required group ids, this widget falls back
/// to rendering the entire SVG (non-interactive).
class JourneySvgMap extends StatefulWidget {
  final String assetPath;
  final int regionCount;
  final int currentRegion; // 1-based
  final ValueChanged<int>? onActiveRegionTap;

  const JourneySvgMap({
    super.key,
    this.assetPath = 'images/map.svg',
    this.regionCount = 9,
    required this.currentRegion,
    this.onActiveRegionTap,
  });

  @override
  State<JourneySvgMap> createState() => _JourneySvgMapState();
}

class _JourneySvgMapState extends State<JourneySvgMap> {
  late Future<_SvgSplitResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadAndSplit();
  }

  @override
  void didUpdateWidget(covariant JourneySvgMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath ||
        oldWidget.regionCount != widget.regionCount) {
      _future = _loadAndSplit();
    }
  }

  Future<_SvgSplitResult> _loadAndSplit() async {
    final raw = await rootBundle.loadString(widget.assetPath);
    return _SvgSplitter.splitIntoRegions(raw, widget.regionCount);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SvgSplitResult>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final res = snap.data!;

        // Fallback: show whole SVG if we couldn't find the region groups.
        if (!res.hasAllRegions) {
          return SvgPicture.string(
            res.fullSvg,
            fit: BoxFit.contain,
          );
        }

        // Render each region as its own layer so we can control filters + taps.
        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                for (int i = 1; i <= widget.regionCount; i++)
                  _RegionLayer(
                    svg: res.regionSvgs[i]!,
                    isCompleted: i < widget.currentRegion,
                    isActive: i == widget.currentRegion,
                    onTap: (i == widget.currentRegion)
                        ? () => widget.onActiveRegionTap?.call(i)
                        : null,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RegionLayer extends StatelessWidget {
  final String svg;
  final bool isCompleted;
  final bool isActive;
  final VoidCallback? onTap;

  const _RegionLayer({
    required this.svg,
    required this.isCompleted,
    required this.isActive,
    required this.onTap,
  });

  static const _inactiveGray = ColorFilter.matrix(<double>[
    // classic luminance grayscale
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final future = !isCompleted && !isActive;
    final child = SvgPicture.string(svg, fit: BoxFit.contain);

    final filtered = future
        ? ColorFiltered(colorFilter: _inactiveGray, child: child)
        : child;

    if (onTap == null) return filtered;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: filtered,
      ),
    );
  }
}

class _SvgSplitResult {
  final String fullSvg;
  final Map<int, String> regionSvgs;
  final bool hasAllRegions;

  const _SvgSplitResult({
    required this.fullSvg,
    required this.regionSvgs,
    required this.hasAllRegions,
  });
}

class _SvgSplitter {
  static _SvgSplitResult splitIntoRegions(String svg, int regionCount) {
    final viewBox = _extractViewBox(svg);
    final defs = _extractDefs(svg);

    final regions = <int, String>{};
    for (int i = 1; i <= regionCount; i++) {
      final group = _extractGroupById(svg, 'region_$i');
      if (group == null) continue;
      regions[i] = _wrapSvg(
        viewBox: viewBox,
        defs: defs,
        body: group,
      );
    }

    final hasAll = regions.length == regionCount;
    return _SvgSplitResult(fullSvg: svg, regionSvgs: regions, hasAllRegions: hasAll);
  }

  static String _wrapSvg({
    required String viewBox,
    required String defs,
    required String body,
  }) {
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">
$defs
$body
</svg>
''';
  }

  static String _extractViewBox(String svg) {
    final m = RegExp(r'viewBox="([^"]+)"', caseSensitive: false).firstMatch(svg);
    return m?.group(1) ?? '0 0 430 850';
  }

  static String _extractDefs(String svg) {
    final m = RegExp(r'<defs\b[^>]*>[\s\S]*?</defs>', caseSensitive: false)
        .firstMatch(svg);
    return m?.group(0) ?? '';
  }

  static String? _extractGroupById(String svg, String id) {
    // Non-greedy capture of the group with that id.
    final re = RegExp(
      r'<g\b[^>]*\bid="' + RegExp.escape(id) + r'"[^>]*>[\s\S]*?</g>',
      caseSensitive: false,
    );
    final m = re.firstMatch(svg);
    return m?.group(0);
  }
}

