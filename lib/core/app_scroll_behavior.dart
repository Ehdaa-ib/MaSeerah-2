import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Shows a light grey scrollbar thumb on scrollable content (Material 3).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  static const Color _thumbGrey = Color(0xFFB8B8B8);

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return RawScrollbar(
      controller: details.controller,
      thumbVisibility: true,
      thickness: 5,
      radius: const Radius.circular(3),
      crossAxisMargin: 2,
      mainAxisMargin: 4,
      thumbColor: _thumbGrey.withValues(alpha: 0.9),
      fadeDuration: const Duration(milliseconds: 220),
      timeToFade: const Duration(milliseconds: 900),
      child: child,
    );
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
