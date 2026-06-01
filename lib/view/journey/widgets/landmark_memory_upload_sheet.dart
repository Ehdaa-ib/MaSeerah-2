import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_colors.dart';
import '../../../core/map_button_styles.dart';
import '../../../core/map_design_tokens.dart';
import '../../../core/map_text_styles.dart';
import '../../../data/firebase/landmark_memory_data_source.dart';
import '../../../l10n/app_localizations.dart';
import '../../../util/wait_for_auth.dart';

/// Memory capture step between landmark content and the challenge (photo required per landmark).
class LandmarkMemoryUploadSheet extends StatefulWidget {
  const LandmarkMemoryUploadSheet({
    super.key,
    required this.width,
    required this.height,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.landmarkOrder,
    required this.catalogJourneyId,
    required this.userJourneyId,
    required this.journeyTitle,
    required this.onClose,
    required this.onContinueToChallenge,
  });

  final double width;
  final double height;
  final String landmarkId;
  final String landmarkTitle;
  final int landmarkOrder;
  final String catalogJourneyId;
  final String userJourneyId;
  final String journeyTitle;
  final VoidCallback onClose;
  final VoidCallback onContinueToChallenge;

  @override
  State<LandmarkMemoryUploadSheet> createState() => _LandmarkMemoryUploadSheetState();
}

class _LandmarkMemoryUploadSheetState extends State<LandmarkMemoryUploadSheet> {
  final _picker = ImagePicker();
  final _memoryDs = LandmarkMemoryDataSource();

  XFile? _selectedFile;
  String _captureSource = 'gallery';
  bool _uploading = false;
  bool _uploadCommitted = false;

  static const double _headerSideSlot = MapDesignTokens.popupHeaderHeight;

  void _applyPickedFile(XFile file, {required String source}) {
    setState(() {
      _selectedFile = file;
      _captureSource = source;
      _uploadCommitted = false;
    });
  }

  Future<void> _takePhoto() async {
    if (_uploading) return;
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1440,
      );
      if (photo == null || !mounted) return;
      _applyPickedFile(photo, source: 'camera');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.memoryUploadPickFailed)),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_uploading) return;
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1440,
      );
      if (photo == null || !mounted) return;
      _applyPickedFile(photo, source: 'gallery');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.memoryUploadPickFailed)),
        );
      }
    }
  }

  void _showSourceSheet() {
    if (_uploading) return;
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.beige,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MapDesignTokens.radiusCard)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: MapDesignTokens.iconMuted()),
              title: Text(l10n.memoryUploadTakePhoto, style: MapTextStyles.bodySmall),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: MapDesignTokens.iconMuted()),
              title: Text(l10n.memoryUploadFromGallery, style: MapTextStyles.bodySmall),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.close, color: MapDesignTokens.closeIconColor()),
              title: Text(l10n.memoryUploadCancel, style: MapTextStyles.bodySmall),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSelection() {
    if (_uploading) return;
    setState(() {
      _selectedFile = null;
      _uploadCommitted = false;
    });
  }

  Future<void> _onNext() async {
    if (_uploading) return;

    final file = _selectedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.memoryUploadPhotoRequired)),
      );
      return;
    }

    if (_uploadCommitted) {
      widget.onContinueToChallenge();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.memoryUploadSignInRequired)),
      );
      return;
    }

    final instanceId = widget.userJourneyId.trim();
    if (instanceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journey session is not ready yet. Please wait a moment and try again.'),
        ),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await waitForAuth();
      final journeyId = LandmarkMemoryDataSource.normalizeCatalogJourneyId(
        catalogJourneyId: widget.catalogJourneyId,
      );
      if (kDebugMode) {
        debugPrint(
          '[LandmarkMemory] save userId=$uid journeyId=$journeyId userJourneyId=$instanceId',
        );
      }
      await _memoryDs.saveLandmarkMemory(
        userId: uid,
        journeyId: journeyId,
        userJourneyId: instanceId,
        journeyTitle: widget.journeyTitle,
        landmarkId: widget.landmarkId,
        landmarkTitle: widget.landmarkTitle,
        landmarkOrder: widget.landmarkOrder,
        file: file,
        source: _captureSource,
      );
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _uploadCommitted = true;
      });
      widget.onContinueToChallenge();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      final l10n = AppLocalizations.of(context)!;
      final detail = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail.contains('rules') || detail.contains('permission')
                ? '${l10n.memoryUploadSaveFailed}\n$detail'
                : l10n.memoryUploadSaveFailed,
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Widget _buildHeader(String title) {
    return SizedBox(
      height: MapDesignTokens.popupHeaderHeight,
      child: Row(
        children: [
          SizedBox(
            width: _headerSideSlot,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: _headerSideSlot,
                minHeight: _headerSideSlot,
              ),
              onPressed: _uploading ? null : widget.onClose,
              icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.brown),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: MapTextStyles.popupTitle,
            ),
          ),
          const SizedBox(width: _headerSideSlot),
        ],
      ),
    );
  }

  Widget _instructionCard(String note) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusChip),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.photo_camera_outlined,
            size: MapDesignTokens.iconStandard,
            color: MapDesignTokens.primaryAccent.withValues(alpha: 0.95),
          ),
          const SizedBox(width: MapDesignTokens.spaceMd),
          Expanded(
            child: Text(
              note,
              style: MapTextStyles.body.copyWith(
                height: 1.45,
                color: AppColors.brown.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadArea(AppLocalizations l10n) {
    return Material(
      color: AppColors.beige.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
      child: InkWell(
        onTap: _uploading ? null : _showSourceSheet,
        borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: MapDesignTokens.spaceLg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MapDesignTokens.radiusCard),
            border: Border.all(color: MapDesignTokens.borderSubtle(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 40,
                  color: AppColors.orange.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: MapDesignTokens.spaceMd),
              Text(
                l10n.memoryUploadTakeOrUpload,
                textAlign: TextAlign.center,
                style: MapTextStyles.bodyBold.copyWith(color: MapDesignTokens.titleColor),
              ),
              const SizedBox(height: MapDesignTokens.spaceXs),
              Text(
                l10n.memoryUploadGalleryOrCamera,
                textAlign: TextAlign.center,
                style: MapTextStyles.caption.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullImagePreview(XFile file) {
    Widget image;
    if (kIsWeb) {
      image = Image.network(file.path, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      image = Image.file(
        File(file.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        image,
        Positioned(
          top: MapDesignTokens.spaceSm,
          right: MapDesignTokens.spaceSm,
          child: GestureDetector(
            onTap: _uploading ? null : _clearSelection,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.65),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _retakeNextRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 12, 22, 22),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _uploading ? null : _showSourceSheet,
              style: MapButtonStyles.secondaryOutlined(),
              child: Text(l10n.memoryUploadRetake),
            ),
          ),
          const SizedBox(width: MapDesignTokens.spaceMd),
          Expanded(
            child: FilledButton(
              onPressed: _uploading ? null : _onNext,
              style: MapButtonStyles.primaryFilled(verticalPadding: 14),
              child: _uploading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      l10n.memoryUploadNext,
                      style: MapTextStyles.buttonLabel,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickPhotoBody(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: MapDesignTokens.paddingLandmarkScroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _instructionCard(l10n.memoryUploadNote),
          const SizedBox(height: MapDesignTokens.spaceLg),
          _uploadArea(l10n),
        ],
      ),
    );
  }

  Widget _previewPhotoBody(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _fullImagePreview(_selectedFile!),
        ),
        SafeArea(
          top: false,
          child: _retakeNextRow(l10n),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasMedia = _selectedFile != null;

    return Container(
      width: widget.width,
      height: widget.height,
      margin: MapDesignTokens.sheetOuterMargin,
      decoration: MapDesignTokens.landmarkSheetDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(l10n.memoryUploadTitle),
          Divider(height: 1, thickness: 1, color: MapDesignTokens.borderSubtle(0.14)),
          Expanded(
            child: hasMedia ? _previewPhotoBody(l10n) : _pickPhotoBody(l10n),
          ),
        ],
      ),
    );
  }
}
