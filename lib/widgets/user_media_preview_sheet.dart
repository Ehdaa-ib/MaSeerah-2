import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../l10n/app_localizations.dart';
import '../service/user_media_actions.dart';
import 'app_network_image.dart';

/// Full-screen preview with share and save (FR-35).
class UserMediaPreviewSheet {
  UserMediaPreviewSheet._();

  static Future<void> show(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? subtitle,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => _UserMediaPreviewDialog(
        imageUrl: imageUrl,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  /// Quick actions from a grid card (share / save). Tap the image to preview.
  static Future<void> showQuickActions(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? subtitle,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.beige,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brown.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (title != null && title.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  title.trim(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.brown,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share_rounded, color: AppColors.brown),
              title: Text(l10n.mediaShare, style: const TextStyle(color: AppColors.brown)),
              onTap: () {
                Navigator.pop(ctx);
                _UserMediaPreviewDialogState.shareFromContext(
                  context,
                  imageUrl: imageUrl,
                  caption: title ?? subtitle,
                );
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.brown),
                title: Text(l10n.mediaSaveToDevice, style: const TextStyle(color: AppColors.brown)),
                onTap: () {
                  Navigator.pop(ctx);
                  _UserMediaPreviewDialogState.saveFromContext(
                    context,
                    imageUrl: imageUrl,
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _UserMediaPreviewDialog extends StatefulWidget {
  const _UserMediaPreviewDialog({
    required this.imageUrl,
    this.title,
    this.subtitle,
  });

  final String imageUrl;
  final String? title;
  final String? subtitle;

  @override
  State<_UserMediaPreviewDialog> createState() => _UserMediaPreviewDialogState();
}

class _UserMediaPreviewDialogState extends State<_UserMediaPreviewDialog> {
  bool _busy = false;

  String? get _caption {
    final t = widget.title?.trim();
    final s = widget.subtitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  static Future<void> shareFromContext(
    BuildContext context, {
    required String imageUrl,
    String? caption,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await UserMediaActions.shareImage(url: imageUrl, caption: caption);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mediaShareFailed)),
      );
    }
  }

  static Future<void> saveFromContext(
    BuildContext context, {
    required String imageUrl,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await UserMediaActions.saveToGallery(imageUrl);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mediaSavedToGallery)),
      );
    } on UserMediaActionException catch (e) {
      if (!context.mounted) return;
      final msg = e.code == 'permission'
          ? l10n.mediaSaveFailed
          : l10n.mediaSaveFailed;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mediaSaveFailed)),
      );
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await UserMediaActions.shareImage(url: widget.imageUrl, caption: _caption);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mediaShareFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await UserMediaActions.saveToGallery(widget.imageUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mediaSavedToGallery)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.mediaSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final heading = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : l10n.mediaPhotoPreview;

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: AppNetworkImage(
                  url: widget.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              heading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.subtitle != null &&
                                widget.subtitle!.trim().isNotEmpty)
                              Text(
                                widget.subtitle!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Spacer(),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ActionChip(
                            icon: Icons.share_rounded,
                            label: l10n.mediaShare,
                            onPressed: _share,
                          ),
                        ),
                        if (!kIsWeb) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionChip(
                              icon: Icons.download_rounded,
                              label: l10n.mediaSaveToDevice,
                              onPressed: _save,
                            ),
                          ),
                        ],
                      ],
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

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
