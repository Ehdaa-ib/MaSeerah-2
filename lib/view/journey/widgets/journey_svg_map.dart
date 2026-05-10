import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

/// Journey map: **PNGs** for artwork, **`map.svg`** only for region paths (taps + clip holes).
///
/// [activeMapAssetPath] is the full-color raster underneath. [inactiveMapAssetPath] is drawn
/// on top and clipped so regions `1..currentRegion` are cut out. Use an empty
/// [inactiveMapAssetPath] to show only the active image (no gray overlay).
///
/// [assetPath] must stay aligned with the PNGs (`class="region_N"` / `region_N` on paths;
/// optional `regionN_decor` and `map_overlay` affect hit-testing only).
class JourneySvgMap extends StatefulWidget {
  /// SVG read for geometry only (not painted).
  final String assetPath;
  /// Full-color map image drawn under the inactive overlay in dual-map mode (e.g. PNG).
  final String activeMapAssetPath;
  /// Inactive map image drawn on top and clipped (e.g. PNG). Use `''` to disable dual-map mode.
  final String inactiveMapAssetPath;
  final int regionCount;
  final int currentRegion; // 1-based
  /// Called when a region is tapped.
  ///
  /// If [allowTapInactive] is false, taps only fire for the active region.
  final ValueChanged<int>? onRegionTap;

  /// If true, all regions are tappable (active/inactive).
  final bool allowTapInactive;

  const JourneySvgMap({
    super.key,
    this.assetPath = 'images/map.svg',
    this.activeMapAssetPath = 'images/map_active.png',
    this.inactiveMapAssetPath = 'images/map_inactive.png',
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

        if (!res.hasAllRegions) {
          if (widget.activeMapAssetPath.isNotEmpty) {
            return Image.asset(
              widget.activeMapAssetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            );
          }
          return const Center(child: Icon(Icons.map_outlined));
        }

        if (widget.inactiveMapAssetPath.isNotEmpty) {
          if (widget.activeMapAssetPath.isEmpty) {
            return _rasterMapWithHits(context, res, top: widget.inactiveMapAssetPath);
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final hit = _SvgHitTester(
                viewBox: res.viewBox,
                regionPaths: res.regionHitPaths,
              );
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final cw = (constraints.maxWidth * dpr).round().clamp(1, 4096);
              final ch = (constraints.maxHeight * dpr).round().clamp(1, 4096);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.activeMapAssetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: cw,
                    cacheHeight: ch,
                    gaplessPlayback: true,
                  ),
                  ClipPath(
                    clipper: _InactiveOverlayClipper(
                      viewBox: res.viewBox,
                      regionPaths: res.regionHitPaths,
                      regionCount: widget.regionCount,
                      currentRegion: widget.currentRegion,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      widget.inactiveMapAssetPath,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: cw,
                      cacheHeight: ch,
                      gaplessPlayback: true,
                    ),
                  ),
                  _regionTapOverlay(context, hit),
                ],
              );
            },
          );
        }

        return _rasterMapWithHits(context, res, top: widget.activeMapAssetPath);
      },
    );
  }

  /// Single full-bleed raster ([top]) with path-based region taps.
  Widget _rasterMapWithHits(
    BuildContext context,
    _SvgSplitResult res, {
    required String top,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hit = _SvgHitTester(
          viewBox: res.viewBox,
          regionPaths: res.regionHitPaths,
        );
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cw = (constraints.maxWidth * dpr).round().clamp(1, 4096);
        final ch = (constraints.maxHeight * dpr).round().clamp(1, 4096);
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              top,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: cw,
              cacheHeight: ch,
              gaplessPlayback: true,
            ),
            _regionTapOverlay(context, hit),
          ],
        );
      },
    );
  }

  Widget _regionTapOverlay(BuildContext context, _SvgHitTester hit) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          final ro = context.findRenderObject();
          if (ro is! RenderBox) return;
          final local = ro.globalToLocal(details.globalPosition);
          final region = hit.hitTest(local, ro.size);
          if (region == null) return;
          if (!widget.allowTapInactive && region != widget.currentRegion) {
            return;
          }
          widget.onRegionTap?.call(region);
        },
      ),
    );
  }
}

class _SvgSplitResult {
  final bool hasAllRegions;
  final _ViewBox viewBox;
  final Map<int, Path> regionHitPaths;

  const _SvgSplitResult({
    required this.hasAllRegions,
    required this.viewBox,
    required this.regionHitPaths,
  });
}

class _SvgSplitter {
  static _SvgSplitResult splitIntoRegions(String svg, int regionCount) {
    final viewBoxRaw = _extractViewBox(svg);
    final viewBox = _ViewBox.parse(viewBoxRaw);
    final hitPaths = <int, Path>{};

    // Fast path: if regions are tagged on paths via class="region_1"/"region1",
    // collect them in one scan (more reliable than regexing with ^ anchors).
    final classTaggedPaths = _extractRegionPathsByClass(svg);

    var foundCount = 0;
    for (int i = 1; i <= regionCount; i++) {
      // Preferred: `<g id="region_N">...</g>` (or any element with id="region_N").
      // Fallback: elements/groups tagged via class e.g. class="region_1" or class="region1".
      final element = _extractRegionElement(svg, i) ?? classTaggedPaths[i];
      if (element == null) continue;
      foundCount++;

      final d = _extractHitPathD(element, i);
      if (d != null) {
        try {
          hitPaths[i] = parseSvgPathData(d);
        } catch (_) {}
      }
      final siblingDecor = _extractSiblingDecorGroup(svg, i);
      if (siblingDecor != null && hitPaths[i] != null) {
        _mergeOverlayPathsIntoRegionHit(hitPaths, siblingDecor, bindRegion: i);
      }
    }

    final String? overlayInner =
        _extractMapOverlayBodyById(svg) ?? _extractLooseOverlayAfterRegion1(svg);
    if (overlayInner != null && overlayInner.isNotEmpty) {
      _mergeOverlayPathsIntoRegionHit(hitPaths, overlayInner, bindRegion: 1);
    }

    final hasAll = foundCount == regionCount;
    return _SvgSplitResult(
      hasAllRegions: hasAll,
      viewBox: viewBox,
      regionHitPaths: hitPaths,
    );
  }

  /// `<g id="map_overlay">...</g>` — buildings/decoration outside region groups.
  static String? _extractMapOverlayBodyById(String svg) {
    final re = RegExp(
      r'<g\b[^>]*\bid="map_overlay"[^>]*>',
      caseSensitive: false,
    );
    final m = re.firstMatch(svg);
    if (m == null) return null;
    final gStart = m.start;
    final firstTagEnd = svg.indexOf('>', gStart);
    if (firstTagEnd == -1) return null;

    var depth = 1;
    var i = firstTagEnd + 1;
    while (i < svg.length) {
      final nextOpen = svg.indexOf('<g', i);
      final nextClose = svg.indexOf('</g', i);
      if (nextClose == -1) return null;

      if (nextOpen != -1 && nextOpen < nextClose) {
        depth++;
        final openEnd = svg.indexOf('>', nextOpen);
        if (openEnd == -1) return null;
        i = openEnd + 1;
        continue;
      }

      depth--;
      final closeEnd = svg.indexOf('>', nextClose);
      if (closeEnd == -1) return null;
      i = closeEnd + 1;

      if (depth == 0) {
        return svg.substring(firstTagEnd + 1, nextClose).trim();
      }
    }
    return null;
  }

  /// Fallback: paths between the region-1 `</g>` and the clip root `</g>` (no overlay id).
  static String? _extractLooseOverlayAfterRegion1(String svg) {
    final re = RegExp(
      r'class="(?:region_1|region1)"[^>]*/>\s*</g>\s*([\s\S]*?)\s*</g>\s*<defs',
      caseSensitive: false,
    );
    final m = re.firstMatch(svg);
    if (m == null) return null;
    final inner = m.group(1)!.trim();
    if (inner.isEmpty) return null;
    if (!RegExp(r'<(path|g|circle|rect|ellipse|polygon|polyline|line)\b',
            caseSensitive: false)
        .hasMatch(inner)) {
      return null;
    }
    return inner;
  }

  static void _mergeOverlayPathsIntoRegionHit(
    Map<int, Path> hitPaths,
    String overlayInner, {
    required int bindRegion,
  }) {
    final existing = hitPaths[bindRegion];
    if (existing == null) return;
    var combined = existing;

    final re = RegExp(
      r'<path\b[^>]*\bd="([^"]+)"',
      caseSensitive: false,
    );
    for (final m in re.allMatches(overlayInner)) {
      final d = m.group(1);
      if (d == null || d.isEmpty) continue;
      try {
        final extra = parseSvgPathData(d);
        combined = Path.combine(PathOperation.union, combined, extra);
      } catch (_) {}
    }
    hitPaths[bindRegion] = combined;
  }

  /// Sibling `<g class="regionN_decor">…</g>` or `id="regionN_decor"` / `region_N_decor`.
  ///
  /// Class matching must **not** use `(?:^|\\s)` around the token: `^` is the start
  /// of the whole SVG, so `class="region2_decor"` would never match.
  static String? _extractSiblingDecorGroup(String svg, int n) {
    for (final id in ['region_${n}_decor', 'region${n}_decor']) {
      final byId = _extractElementById(svg, id);
      if (byId != null) return byId;
    }
    final ns = n.toString();
    final re = RegExp(
      r'<g\b[^>]*class="\s*(?:[^"]*\s)?region_?' +
          ns +
          r'_decor(?:\s[^"]*)?"[^>]*>',
      caseSensitive: false,
    );
    final m = re.firstMatch(svg);
    if (m == null) return null;
    return _extractGGroupByDepth(svg, m.start);
  }

  /// Full `<g …>…</g>` starting at [gStart] (balanced nested `<g>`).
  static String? _extractGGroupByDepth(String svg, int gStart) {
    final firstTagEnd = svg.indexOf('>', gStart);
    if (firstTagEnd == -1) return null;
    var depth = 1;
    var i = firstTagEnd + 1;
    while (i < svg.length) {
      final nextOpen = svg.indexOf('<g', i);
      final nextClose = svg.indexOf('</g', i);
      if (nextClose == -1) return null;

      if (nextOpen != -1 && nextOpen < nextClose) {
        depth++;
        final openEnd = svg.indexOf('>', nextOpen);
        if (openEnd == -1) return null;
        i = openEnd + 1;
        continue;
      }

      depth--;
      final closeEnd = svg.indexOf('>', nextClose);
      if (closeEnd == -1) return null;
      i = closeEnd + 1;

      if (depth == 0) {
        return svg.substring(gStart, closeEnd + 1);
      }
    }
    return null;
  }

  static String _extractViewBox(String svg) {
    final m = RegExp(r'viewBox="([^"]+)"', caseSensitive: false).firstMatch(svg);
    return m?.group(1) ?? '0 0 860 1700';
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
    // Whole token inside class="...". Do not use `^` here — that anchors the whole SVG.
    // Word boundaries work after the opening quote (e.g. class="region_2").
    return r'\bregion_?' + n.toString() + r'\b';
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
      return const _ViewBox(x: 0, y: 0, width: 860, height: 1700);
    }
    double p(int i, double fallback) => double.tryParse(parts[i]) ?? fallback;
    return _ViewBox(x: p(0, 0), y: p(1, 0), width: p(2, 860), height: p(3, 1700));
  }
}

/// Transforms a path from SVG user space ([viewBox]) to Stack layout [size]
/// using the same [BoxFit.contain] letterboxing as [_SvgHitTester].
Path _transformSvgPathToLayout(Path source, Size size, _ViewBox viewBox) {
  final sx = size.width / viewBox.width;
  final sy = size.height / viewBox.height;
  final scale = sx < sy ? sx : sy;
  final dx = (size.width - viewBox.width * scale) / 2;
  final dy = (size.height - viewBox.height * scale) / 2;
  final m = Matrix4.identity()
    ..translateByDouble(dx, dy, 0, 1.0)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-viewBox.x, -viewBox.y, 0, 1.0);
  return source.transform(m.storage);
}

/// Keeps the inactive map only **outside** regions `1..currentRegion` so the
/// active map shows through completed and current areas.
class _InactiveOverlayClipper extends CustomClipper<Path> {
  _InactiveOverlayClipper({
    required this.viewBox,
    required this.regionPaths,
    required this.regionCount,
    required this.currentRegion,
  });

  final _ViewBox viewBox;
  final Map<int, Path> regionPaths;
  final int regionCount;
  final int currentRegion;

  @override
  Path getClip(Size size) {
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    Path? holes;
    final maxR = currentRegion.clamp(0, regionCount);
    for (var i = 1; i <= maxR; i++) {
      final p = regionPaths[i];
      if (p == null) continue;
      final local = _transformSvgPathToLayout(p, size, viewBox);
      holes = holes == null
          ? local
          : Path.combine(PathOperation.union, holes, local);
    }
    if (holes == null) return outer;
    return Path.combine(PathOperation.difference, outer, holes);
  }

  @override
  bool shouldReclip(covariant _InactiveOverlayClipper old) {
    return old.currentRegion != currentRegion ||
        old.regionCount != regionCount ||
        old.viewBox != viewBox ||
        old.regionPaths != regionPaths;
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

