import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/user_media_card_actions.dart';
import '../journey/journey_history_memories_screen.dart';
import '../../util/journey_history_scope.dart';

enum ProfileSectionKind { journeys, feedbacks, photos }

/// Full list for a profile section (journeys, feedbacks, or photos).
class ProfileSectionListScreen extends StatelessWidget {
  const ProfileSectionListScreen({
    super.key,
    required this.title,
    required this.kind,
    required this.journeys,
    required this.feedbacks,
    required this.photos,
    required this.journeyTitleFor,
    required this.formatExactDate,
    required this.onOpenPhoto,
  });

  final String title;
  final ProfileSectionKind kind;
  final List<Map<String, dynamic>> journeys;
  final List<Map<String, dynamic>> feedbacks;
  final List<Map<String, dynamic>> photos;
  final String Function(Map<String, dynamic> item) journeyTitleFor;
  final String Function(DateTime? date) formatExactDate;
  final void Function(Map<String, dynamic> photo) onOpenPhoto;

  static const double _cardHeight = 160;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.beige,
        foregroundColor: AppColors.brown,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.brown),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (kind) {
      case ProfileSectionKind.journeys:
        if (journeys.isEmpty) return _emptyMessage(l10n.profileNoJourneysYet);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: journeys.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _journeyCard(context, journeys[i]),
        );
      case ProfileSectionKind.feedbacks:
        return _emptyMessage(l10n.profileNoJourneysYet);
      case ProfileSectionKind.photos:
        if (photos.isEmpty) return _emptyMessage(l10n.profileNoPhotosYet);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: photos.length,
          itemBuilder: (_, i) {
            final rawUrl = photos[i]['url'];
            final url = rawUrl is String ? rawUrl.trim() : rawUrl?.toString().trim() ?? '';
            if (url.isEmpty) return const SizedBox.shrink();
            return _photoTile(context, photos[i]);
          },
        );
    }
  }

  Widget _emptyMessage(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.beige.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.brown.withValues(alpha: 0.2)),
        ),
        child: Text(
          text,
          style: const TextStyle(color: AppColors.brown, fontSize: 15),
        ),
      ),
    );
  }

  Widget _journeyCard(BuildContext context, Map<String, dynamic> journey) {
    final title = journeyTitleFor(journey);
    final dateStr = journey['date']?.toString() ?? '';
    final journeyId = journey['journeyId']?.toString() ?? '';
    return Material(
      color: AppColors.beige.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: journeyId.isEmpty
            ? null
            : () {
                final scope = JourneyHistoryScope.fromProfileRow(journey);
                final completedAt = journey['completedAt'] is DateTime
                    ? journey['completedAt'] as DateTime
                    : (journey['sort'] is DateTime ? journey['sort'] as DateTime : scope.completedAt);
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => JourneyHistoryMemoriesScreen(
                      journeyId: scope.catalogJourneyId,
                      journeyName: title,
                      historyDocId: journey['historyDocId']?.toString() ?? scope.historyDocId,
                      completionDocId:
                          journey['completionDocId']?.toString() ?? scope.completionDocId,
                      userJourneyId:
                          journey['userJourneyId']?.toString() ?? scope.userJourneyId,
                      completedAt: completedAt,
                    ),
                  ),
                );
              },
        child: Container(
          width: double.infinity,
          height: _cardHeight,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brown.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.route, size: 18, color: AppColors.brown.withValues(alpha: 0.85)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.brown,
                      ),
                    ),
                  ),
                ],
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: AppColors.brown.withValues(alpha: 0.6)),
                    const SizedBox(width: 6),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.brown.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedbackCard(BuildContext context, Map<String, dynamic> fb) {
    final stars = (fb['rating'] as num?)?.toInt() ?? 0;
    final photos = (fb['photos'] as List?)?.whereType<String>().toList() ?? [];
    final journeyName = journeyTitleFor(fb);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.beige.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 14, color: AppColors.brown.withValues(alpha: 0.75)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  journeyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.brown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < stars ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 16,
              ),
            ),
          ),
          if ((fb['comment']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              fb['comment']!.toString(),
              style: const TextStyle(fontSize: 13, color: AppColors.brown, height: 1.35),
            ),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _photoThumb(
                  context,
                  photos[i],
                  journeyName: journeyName,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            (fb['dateLabel'] as String?)?.trim().isNotEmpty == true
                ? fb['dateLabel'] as String
                : formatExactDate(fb['date'] as DateTime?),
            style: TextStyle(
              fontSize: 11,
              color: AppColors.brown.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoTile(BuildContext context, Map<String, dynamic> photo) {
    final url = photo['url']?.toString().trim() ?? '';
    final landmark = photo['landmarkTitle']?.toString().trim();
    final journey = photo['journeyName']?.toString().trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: AppColors.brown.withValues(alpha: 0.1),
        child: InkWell(
          onTap: () => onOpenPhoto(photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                error: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.brown.withValues(alpha: 0.45),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: UserMediaCardActionsButton(
                  imageUrl: url,
                  title: (landmark != null && landmark.isNotEmpty) ? landmark : journey,
                  subtitle: journey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoThumb(
    BuildContext context,
    String url, {
    String? journeyName,
  }) {
    final photo = {
      'url': url,
      if (journeyName != null) 'journeyName': journeyName,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onOpenPhoto(photo),
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                url: url,
                fit: BoxFit.cover,
                width: 64,
                height: 64,
                memCacheWidth: 128,
              ),
              Positioned(
                top: 2,
                right: 2,
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
  }
}
