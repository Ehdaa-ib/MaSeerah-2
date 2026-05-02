import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_drawing/path_drawing.dart';

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
  /// Called when a region is tapped.
  ///
  /// If [allowTapInactive] is false, taps only fire for the active region.
  final ValueChanged<int>? onRegionTap;

  /// If true, all regions are tappable (active/inactive).
  /// Inactive regions are still rendered with a grayscale filter.
  final bool allowTapInactive;

  const JourneySvgMap({
    super.key,
    this.assetPath = 'images/map.svg',
    this.regionCount = 9,
    required this.currentRegion,
    this.onRegionTap,
    this.allowTapInactive = false,
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

        // Render each region as its own layer so we can control filters.
        // Taps are handled via real hit-testing against the region path data,
        // otherwise InkWell would treat each region layer as a full-rect hit area.
        return LayoutBuilder(
          builder: (context, constraints) {
            final hit = _SvgHitTester(
              viewBox: res.viewBox,
              regionPaths: res.regionHitPaths,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                // Match SVG paint order: earlier elements are "behind".
                // Figma exports these regions in 9..1 order, so render from
                // regionCount down to 1 to keep decorations visible.
                for (int i = widget.regionCount; i >= 1; i--)
                  _RegionLayer(
                    svg: res.regionSvgs[i]!,
                    isCompleted: i < widget.currentRegion,
                    isActive: i == widget.currentRegion,
                    onTap: null,
                  ),
                // Decorations should be painted on top of all regions, otherwise
                // later region shapes can cover them.
                for (int i = widget.regionCount; i >= 1; i--)
                  if (res.regionDecorSvgs[i] != null)
                    _RegionLayer(
                      svg: res.regionDecorSvgs[i]!,
                      isCompleted: i < widget.currentRegion,
                      isActive: i == widget.currentRegion,
                      onTap: null,
                    ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      final ro = context.findRenderObject();
                      if (ro is! RenderBox) return;
                      final local = ro.globalToLocal(details.globalPosition);
                      final region = hit.hitTest(local, ro.size);
                      if (region == null) return;
                      if (!widget.allowTapInactive && region != widget.currentRegion) return;
                      widget.onRegionTap?.call(region);
                    },
                  ),
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
  final Map<int, String> regionDecorSvgs;
  final bool hasAllRegions;
  final _ViewBox viewBox;
  final Map<int, Path> regionHitPaths;

  const _SvgSplitResult({
    required this.fullSvg,
    required this.regionSvgs,
    required this.regionDecorSvgs,
    required this.hasAllRegions,
    required this.viewBox,
    required this.regionHitPaths,
  });
}

class _SvgSplitter {
  static _SvgSplitResult splitIntoRegions(String svg, int regionCount) {
    final viewBoxRaw = _extractViewBox(svg);
    final viewBox = _ViewBox.parse(viewBoxRaw);
    final defs = _extractDefs(svg);
    final rootGroupOpen = _extractRootGroupOpen(svg);

    final regions = <int, String>{};
    final decorRegions = <int, String>{};
    final hitPaths = <int, Path>{};

    // Fast path: if regions are tagged on paths via class="region_1"/"region1",
    // collect them in one scan (more reliable than regexing with ^ anchors).
    final classTaggedPaths = _extractRegionPathsByClass(svg);

    for (int i = 1; i <= regionCount; i++) {
      // Preferred: `<g id="region_N">...</g>` (or any element with id="region_N").
      // Fallback: elements/groups tagged via class e.g. class="region_1" or class="region1".
      final element = _extractRegionElement(svg, i) ?? classTaggedPaths[i];
      if (element == null) continue;

      final split = _splitRegionBaseAndDecor(element, i);
      regions[i] = _wrapSvg(
        viewBox: viewBoxRaw,
        defs: defs,
        rootGroupOpen: rootGroupOpen,
        body: split.base,
      );

      if (split.decor != null) {
        decorRegions[i] = _wrapSvg(
          viewBox: viewBoxRaw,
          defs: defs,
          rootGroupOpen: rootGroupOpen,
          body: split.decor!,
        );
      }

      final d = _extractHitPathD(element, i);
      if (d != null) {
        try {
          hitPaths[i] = parseSvgPathData(d);
        } catch (_) {}
      }
    }

    final hasAll = regions.length == regionCount;
    return _SvgSplitResult(
      fullSvg: svg,
      regionSvgs: regions,
      regionDecorSvgs: decorRegions,
      hasAllRegions: hasAll,
      viewBox: viewBox,
      regionHitPaths: hitPaths,
    );
  }

  static String _wrapSvg({
    required String viewBox,
    required String defs,
    required String? rootGroupOpen,
    required String body,
  }) {
    final rootOpen = rootGroupOpen ?? '';
    final rootClose = rootGroupOpen != null ? '\n</g>' : '';
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="$viewBox">
$defs
$rootOpen
$body$rootClose
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

  static String? _extractRootGroupOpen(String svg) {
    // Capture the first <g ...> tag right under <svg>. This commonly contains
    // the global clip-path used by the export (e.g. clip-path="url(#a)").
    final m = RegExp(r'<svg\b[^>]*>[\s\S]*?(<g\b[^>]*>)', caseSensitive: false)
        .firstMatch(svg);
    return m?.group(1);
  }

  static String? _extractElementById(String svg, String id) {
    final escaped = RegExp.escape(id);

    // Case 1: a group with children.
    final group = RegExp(
      r'<g\b[^>]*\bid="' + escaped + r'"[^>]*>[\s\S]*?</g>',
      caseSensitive: false,
    ).firstMatch(svg);
    if (group != null) return group.group(0);

    // Case 2: a self-closing element (common for path/rect/etc).
    final selfClosing = RegExp(
      r'<[a-zA-Z_][^>]*\bid="' + escaped + r'"[^>]*/>',
      caseSensitive: false,
    ).firstMatch(svg);
    if (selfClosing != null) return selfClosing.group(0);

    // Case 3: an element with explicit closing tag (rare for paths, but possible).
    final normal = RegExp(
      r'<([a-zA-Z_][^>]*)\bid="' + escaped + r'"[^>]*>[\s\S]*?</[a-zA-Z_]+>',
      caseSensitive: false,
    ).firstMatch(svg);
    return normal?.group(0);
  }

  static String? _extractRegionElement(String svg, int regionNumber) {
    // 1) id="region_N"
    final byId = _extractElementById(svg, 'region_$regionNumber');
    if (byId != null) return byId;

    // 2) class="region_N" / class="regionN" (possibly with other classes too)
    // Prefer the *enclosing* <g> that contains the region path so decorations
    // inside that group are included and grayed together.
    final enclosingGroup = _extractEnclosingGroupForRegionPath(svg, regionNumber);
    if (enclosingGroup != null) return enclosingGroup;

    // Then try a group directly tagged with the region token.
    final byClassGroup = _extractGroupByRegionClass(svg, regionNumber);
    if (byClassGroup != null) return byClassGroup;

    // Finally: a single element carrying the region class.
    return _extractElementByRegionClass(svg, regionNumber);
  }

  static String _regionClassPattern(int n) {
    // Matches token region_1 or region1 as whole class token.
    // This pattern is used *inside* a class attribute value, so we avoid ^/$.
    // Example: class="foo region_2 bar" or class="region9"
    return r'(?:\s|^)region_?' + n.toString() + r'(?:\s|$)';
  }

  static String? _extractGroupByRegionClass(String svg, int regionNumber) {
    final token = _regionClassPattern(regionNumber);
    final re = RegExp(
      r'<g\b[^>]*>[\s\S]*?class="[^"]*' + token + r'[^"]*"[\s\S]*?</g>',
      caseSensitive: false,
    );
    final m = re.firstMatch(svg);
    return m?.group(0);
  }

  static String? _extractElementByRegionClass(String svg, int regionNumber) {
    final token = _regionClassPattern(regionNumber);

    final selfClosing = RegExp(
      r'<[a-zA-Z_][^>]*class="[^"]*' + token + r'[^"]*"[^>]*/>',
      caseSensitive: false,
    ).firstMatch(svg);
    if (selfClosing != null) return selfClosing.group(0);

    final normal = RegExp(
      r'<[a-zA-Z_][^>]*class="[^"]*' + token + r'[^"]*"[^>]*>[\s\S]*?</[a-zA-Z_]+>',
      caseSensitive: false,
    ).firstMatch(svg);
    return normal?.group(0);
  }

  static String? _extractFirstPathD(String elementSvg) {
    final m = RegExp(r'<path\b[^>]*\bd="([^"]+)"', caseSensitive: false)
        .firstMatch(elementSvg);
    return m?.group(1);
  }

  static String? _extractHitPathD(String elementSvg, int regionNumber) {
    // Prefer the path that is explicitly tagged with the region class.
    final token = _regionClassPattern(regionNumber);
    final tagged = RegExp(
      r'<path\b[^>]*class="[^"]*' + token + r'[^"]*"[^>]*\bd="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(elementSvg);
    if (tagged != null) return tagged.group(1);
    return _extractFirstPathD(elementSvg);
  }

  static ({String base, String? decor}) _splitRegionBaseAndDecor(
    String elementSvg,
    int regionNumber,
  ) {
    // Prefer the region-tagged <path> as the base painted shape.
    // Everything else in the enclosing group is treated as decor to be drawn
    // on top of all regions (so it doesn't get covered by other region shapes).
    final token = _regionClassPattern(regionNumber);
    final basePathRe = RegExp(
      r'(<path\b[^>]*class="[^"]*' + token + r'[^"]*"[^>]*/?>)',
      caseSensitive: false,
    );
    final m = basePathRe.firstMatch(elementSvg);
    if (m == null) return (base: elementSvg, decor: null);

    final base = m.group(1)!;
    final removedOnce = elementSvg.replaceFirst(base, '');

    final hasMoreShapes = RegExp(
      r'<path\b|<rect\b|<circle\b|<ellipse\b|<polygon\b|<polyline\b|<line\b',
      caseSensitive: false,
    ).hasMatch(removedOnce);

    if (!hasMoreShapes) return (base: base, decor: null);

    return (base: base, decor: removedOnce);
  }

  static String? _extractEnclosingGroupForRegionPath(String svg, int regionNumber) {
    // Regex-based group extraction becomes unreliable/slow on big SVGs.
    // Instead: locate the first <path ... class="...regionN...">, then walk
    // outward to the enclosing <g>...</g> by counting nested group tags.
    final token = _regionClassPattern(regionNumber);
    final pathRe = RegExp(
      r'<path\b[^>]*class="[^"]*' + token + r'[^"]*"[^>]*>',
      caseSensitive: false,
    );
    final m = pathRe.firstMatch(svg);
    if (m == null) return null;

    final pathStart = m.start;
    final gStart = svg.lastIndexOf('<g', pathStart);
    if (gStart < 0) return null;

    // Count the initial <g ...> as depth 1.
    int depth = 1;
    final firstTagEnd = svg.indexOf('>', gStart);
    if (firstTagEnd == -1) return null;
    int i = firstTagEnd + 1;
    while (i < svg.length) {
      final nextOpen = svg.indexOf('<g', i);
      final nextClose = svg.indexOf('</g', i);

      if (nextClose == -1) return null;

      if (nextOpen != -1 && nextOpen < nextClose) {
        // Found a nested open before the next close.
        depth += 1;
        final openEnd = svg.indexOf('>', nextOpen);
        if (openEnd == -1) return null;
        i = openEnd + 1;
        continue;
      }

      // Found a close.
      depth -= 1;
      final closeEnd = svg.indexOf('>', nextClose);
      if (closeEnd == -1) return null;
      i = closeEnd + 1;

      if (depth == 0) {
        return svg.substring(gStart, i);
      }
    }

    return null;
  }

  static Map<int, String> _extractRegionPathsByClass(String svg) {
    final out = <int, String>{};
    final re = RegExp(
      r'<path\b[^>]*\bclass="([^"]+)"[^>]*>',
      caseSensitive: false,
    );

    for (final m in re.allMatches(svg)) {
      final classes = m.group(1) ?? '';
      final n = _parseRegionNumberFromClasses(classes);
      if (n == null) continue;
      // Grab the full <path ...> tag match.
      out[n] ??= m.group(0)!;
    }
    return out;
  }

  static int? _parseRegionNumberFromClasses(String classes) {
    final tokens = classes.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    for (final t in tokens) {
      final mm = RegExp(r'^region_?([1-9])$', caseSensitive: false).firstMatch(t);
      if (mm != null) return int.tryParse(mm.group(1)!);
    }
    return null;
  }
}

class _ViewBox {
  final double x;
  final double y;
  final double width;
  final double height;

  const _ViewBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  static _ViewBox parse(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != 4) {
      return const _ViewBox(x: 0, y: 0, width: 430, height: 850);
    }
    double p(int i, double fallback) => double.tryParse(parts[i]) ?? fallback;
    return _ViewBox(x: p(0, 0), y: p(1, 0), width: p(2, 430), height: p(3, 850));
  }
}

class _SvgHitTester {
  final _ViewBox viewBox;
  final Map<int, Path> regionPaths;

  const _SvgHitTester({required this.viewBox, required this.regionPaths});

  int? hitTest(Offset localPosition, Size size) {
    if (regionPaths.isEmpty) return null;

    // Match BoxFit.contain mapping from viewBox -> widget size.
    final sx = size.width / viewBox.width;
    final sy = size.height / viewBox.height;
    final scale = sx < sy ? sx : sy;

    final dx = (size.width - viewBox.width * scale) / 2;
    final dy = (size.height - viewBox.height * scale) / 2;

    final x = (localPosition.dx - dx) / scale + viewBox.x;
    final y = (localPosition.dy - dy) / scale + viewBox.y;
    final p = Offset(x, y);

    final keys = regionPaths.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final k in keys) {
      final path = regionPaths[k]!;
      if (path.contains(p)) return k;
    }
    return null;
  }
}

