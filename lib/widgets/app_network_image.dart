import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network image with sensible cache sizing (ignores non-finite width/height).
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
    this.error,
    this.placeholder,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;
  final Widget? error;
  final Widget? placeholder;

  static int? _safeCacheDimension(double? logical, int? explicit) {
    if (explicit != null && explicit > 0) return explicit;
    if (logical == null || !logical.isFinite || logical <= 0) return null;
    return (logical * 2).round();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) {
      return _wrap(_fallback());
    }

    final cacheW = _safeCacheDimension(width, memCacheWidth);
    final cacheH = _safeCacheDimension(height, memCacheHeight);

    Widget image = CachedNetworkImage(
      imageUrl: trimmed,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      placeholder: (_, _) =>
          placeholder ??
          ColoredBox(
            color: Colors.grey.shade200,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (_, _, _) => error ?? _fallback(),
    );

    return _wrap(image);
  }

  Widget _wrap(Widget child) {
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }

  Widget _fallback() {
    return error ??
        ColoredBox(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        );
  }
}
