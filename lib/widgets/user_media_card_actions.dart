import 'package:flutter/material.dart';

import 'user_media_preview_sheet.dart';

/// Overflow menu on photo cards (profile grid, journey memories).
class UserMediaCardActionsButton extends StatelessWidget {
  const UserMediaCardActionsButton({
    super.key,
    required this.imageUrl,
    this.title,
    this.subtitle,
  });

  final String imageUrl;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => UserMediaPreviewSheet.showQuickActions(
          context,
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
        ),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
