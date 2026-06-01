import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/error_messages.dart';
import '../../data/firebase/feedback_data_source.dart';
import '../../data/firebase/journey_completion_data_source.dart';
import '../../data/firebase/landmark_memory_data_source.dart';
import '../../util/journey_history_scope.dart';
import '../../l10n/app_localizations.dart';
import '../../model/feedback.dart';
import '../../model/landmark_memory.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/user_media_card_actions.dart';
import '../../widgets/user_media_preview_sheet.dart';

/// Journey detail from profile: landmark photos, then feedback for this journey only.
class JourneyHistoryMemoriesScreen extends StatefulWidget {
  const JourneyHistoryMemoriesScreen({
    super.key,
    required this.journeyId,
    required this.journeyName,
    this.historyDocId,
    this.completionDocId,
    this.userJourneyId,
    this.completedAt,
  });

  final String journeyId;
  final String journeyName;
  final String? historyDocId;
  final String? completionDocId;
  final String? userJourneyId;
  final DateTime? completedAt;

  @override
  State<JourneyHistoryMemoriesScreen> createState() => _JourneyHistoryMemoriesScreenState();
}

class _JourneyHistoryMemoriesScreenState extends State<JourneyHistoryMemoriesScreen> {
  final _memoryDs = LandmarkMemoryDataSource();
  final _feedbackDs = FeedbackDataSource();
  final _completionDs = JourneyCompletionDataSource();

  List<LandmarkMemory>? _memories;
  FeedbackEntry? _feedback;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'sign_in';
      });
      return;
    }
    try {
      var instanceId = JourneyHistoryScope.resolveInstanceId({
        'journeyId': widget.journeyId,
        'userJourneyId': widget.userJourneyId,
        'historyDocId': widget.historyDocId,
        'completionDocId': widget.completionDocId,
      })?.trim() ?? '';

      // Perf: skip full history scan when profile already passed a valid instance id.
      if (instanceId.isEmpty &&
          (widget.completionDocId?.trim().isNotEmpty == true ||
              widget.historyDocId?.trim().isNotEmpty == true)) {
        instanceId = (await _completionDs.resolvePlaythroughInstanceId(
              userId: uid,
              catalogJourneyId: widget.journeyId,
              completionDocId: widget.completionDocId,
              historyDocId: widget.historyDocId,
              completedAt: widget.completedAt,
            ))
                ?.trim() ??
            '';
      }

      if (instanceId.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[JourneyHistory] missing userJourneyId journeyId=${widget.journeyId} '
            'completionDocId=${widget.completionDocId} historyDocId=${widget.historyDocId} '
            'completedAt=${widget.completedAt}',
          );
        }
        if (!mounted) return;
        setState(() {
          _memories = const [];
          _feedback = null;
          _loading = false;
          _error = null;
        });
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[JourneyHistory] load photos journeyId=${widget.journeyId} '
          'userJourneyId=$instanceId historyDocId=${widget.historyDocId} '
          'completedAt=${widget.completedAt}',
        );
      }

      final results = await Future.wait([
        _memoryDs.fetchMemoriesForInstance(
          userId: uid,
          userJourneyId: instanceId,
          catalogJourneyIdForMisplacedDocs: widget.journeyId,
        ),
        _feedbackDs.findForInstance(
          userId: uid,
          userJourneyId: instanceId,
          legacyCatalogJourneyId: widget.journeyId,
        ),
      ]);
      final list = results[0] as List<LandmarkMemory>;
      list.sort((a, b) {
        final oa = a.landmarkOrder;
        final ob = b.landmarkOrder;
        if (oa != ob) return oa.compareTo(ob);
        final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      if (kDebugMode) {
        for (final m in list) {
          debugPrint(
            '[JourneyHistory] photo memoryId=${m.id} '
            'storedUserJourneyId=${m.userJourneyId ?? "(none)"} '
            'journeyId=${m.journeyId} landmark=${m.landmarkId}',
          );
        }
        debugPrint(
          '[JourneyHistory] display userJourneyId=$instanceId '
          'photoCount=${list.length} feedback=${results[1] != null}',
        );
      }
      if (!mounted) return;
      setState(() {
        _memories = list;
        _feedback = results[1] as FeedbackEntry?;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = toUserFriendlyMessage(e);
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  void _openPhotoUrl(String url, {String? title, String? subtitle}) {
    UserMediaPreviewSheet.show(
      context,
      imageUrl: url,
      title: title,
      subtitle: subtitle,
    );
  }

  void _openPhoto(LandmarkMemory memory) {
    if (memory.isVideo) return;
    final place = memory.landmarkTitle.trim().isNotEmpty
        ? memory.landmarkTitle
        : 'Landmark';
    _openPhotoUrl(
      memory.mediaUrl,
      title: place,
      subtitle: memory.journeyTitle.trim().isNotEmpty ? memory.journeyTitle : widget.journeyName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final memories = _memories ?? const <LandmarkMemory>[];
    final photoMemories = memories.where((m) => !m.isVideo).toList();
    final hasPhotos = photoMemories.isNotEmpty;
    final fb = _feedback;
    final hasFeedback = fb != null;

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.journeyName,
              style: const TextStyle(
                color: AppColors.brown,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l10n.journeySummaryTitle,
              style: TextStyle(
                color: AppColors.brown.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brown))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error == 'sign_in' ? l10n.journeyListSignInPrompt : _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.brown),
                    ),
                  ),
                )
              : (!hasPhotos && !hasFeedback)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          l10n.journeyDetailEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.45,
                            color: AppColors.brown.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        if (hasPhotos) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                l10n.journeyDetailPhotosTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brown,
                                ),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.72,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final m = photoMemories[index];
                                  return _PlacePhotoCard(
                                    memory: m,
                                    placeName: m.landmarkTitle.trim().isNotEmpty
                                        ? m.landmarkTitle
                                        : 'Landmark',
                                    dateLabel: _formatDate(m.createdAt),
                                    journeyName: widget.journeyName,
                                    onTap: () => _openPhoto(m),
                                  );
                                },
                                childCount: photoMemories.length,
                              ),
                            ),
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, hasPhotos ? 16 : 16, 16, 8),
                            child: Text(
                              l10n.journeyDetailFeedbackTitle,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brown,
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            child: hasFeedback
                                ? _JourneyFeedbackCard(
                                    feedback: _feedback!,
                                    dateLabel: _formatDate(_feedback!.createdAt),
                                    journeyName: widget.journeyName,
                                    onOpenPhoto: (url) => _openPhotoUrl(
                                      url,
                                      title: widget.journeyName,
                                    ),
                                  )
                                : Text(
                                    l10n.journeyDetailNoFeedback,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color: AppColors.brown.withValues(alpha: 0.8),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _PlacePhotoCard extends StatelessWidget {
  const _PlacePhotoCard({
    required this.memory,
    required this.placeName,
    required this.dateLabel,
    required this.journeyName,
    this.onTap,
  });

  final LandmarkMemory memory;
  final String placeName;
  final String dateLabel;
  final String journeyName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Perf: isolate photo tile repaints from the scroll view.
    return RepaintBoundary(
      child: Material(
      color: AppColors.beige,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AppNetworkImage(
                    url: memory.mediaUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    error: ColoredBox(
                      color: AppColors.brown.withValues(alpha: 0.06),
                      child: const Icon(Icons.broken_image_outlined, color: AppColors.brown),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: UserMediaCardActionsButton(
                      imageUrl: memory.mediaUrl,
                      title: placeName,
                      subtitle: journeyName,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    placeName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brown,
                      height: 1.2,
                    ),
                  ),
                  if (dateLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.brown.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _JourneyFeedbackCard extends StatelessWidget {
  const _JourneyFeedbackCard({
    required this.feedback,
    required this.dateLabel,
    required this.journeyName,
    required this.onOpenPhoto,
  });

  final FeedbackEntry feedback;
  final String dateLabel;
  final String journeyName;
  final void Function(String url) onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final comment = feedback.overallComment.trim();
    final photos = feedback.photos.where((u) => u.trim().startsWith('http')).toList();
    final adminReplies = feedback.adminResponses.where((r) => r.message.trim().isNotEmpty).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FeedbackRatingRow(
            label: l10n.journeyDetailFeedbackOverall,
            value: feedback.overallRating,
          ),
          const SizedBox(height: 8),
          _FeedbackRatingRow(
            label: l10n.journeyDetailFeedbackContent,
            value: feedback.contentRating,
          ),
          const SizedBox(height: 8),
          _FeedbackRatingRow(
            label: l10n.journeyDetailFeedbackRecommendations,
            value: feedback.recommendationRating,
          ),
          const SizedBox(height: 8),
          _FeedbackRatingRow(
            label: l10n.journeyDetailFeedbackChallenges,
            value: feedback.challengeRating,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.journeyDetailFeedbackCommentLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.brown,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            comment.isNotEmpty ? comment : l10n.journeyDetailFeedbackNoComment,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.brown.withValues(alpha: comment.isNotEmpty ? 1 : 0.65),
              fontStyle: comment.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (adminReplies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.journeyDetailFeedbackAdminReply,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 6),
            ...adminReplies.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  r.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.brown,
                  ),
                ),
              ),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              l10n.journeyDetailFeedbackPhotos,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brown,
              ),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final url = photos[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Material(
                    color: AppColors.brown.withValues(alpha: 0.06),
                    child: InkWell(
                      onTap: () => onOpenPhoto(url),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(
                            url: url,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: UserMediaCardActionsButton(
                              imageUrl: url,
                              title: journeyName,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          if (dateLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.brown.withValues(alpha: 0.65),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackRatingRow extends StatelessWidget {
  const _FeedbackRatingRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final stars = value.clamp(0, 5);
    final showEmpty = stars <= 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.brown.withValues(alpha: 0.9),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: showEmpty
              ? Text(
                  '—',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.brown.withValues(alpha: 0.5),
                  ),
                )
              : Row(
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Icon(
                        i < stars ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
