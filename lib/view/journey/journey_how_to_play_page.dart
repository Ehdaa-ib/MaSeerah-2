import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/map_button_styles.dart';
import '../../core/map_text_styles.dart';
import '../../core/error_messages.dart';
import '../../data/firebase/journey_data_source.dart';
import '../../data/firebase/journey_progress_data_source.dart';
import '../../data/firebase/order_data_source.dart';
import '../../data/repoImp/journey_repository_firebase.dart';
import '../../data/repoImp/order_repository_firebase.dart';
import '../../l10n/app_localizations.dart';
import '../../service/access_service.dart';
import 'journey_map_screen.dart';

/// How the instructions screen was opened (drives primary button label and behavior).
enum JourneyHowToPlayPresentation {
  /// After payment or first-ever start from purchase; primary saves [hasSeenHowToPlay] then opens the map.
  mandatoryFirstTime,

  /// From the ! control on the purchase screen; primary opens the map without updating the seen flag.
  manualFromPurchase,
}

/// One-time instructions before the map (mandatory), or optional replay from the journey details screen (!).
class JourneyHowToPlayPage extends StatefulWidget {
  const JourneyHowToPlayPage({
    super.key,
    required this.catalogJourneyId,
    required this.journeyTitle,
    required this.landmarksJourneyId,
    required this.presentation,
    this.needsProgressBootstrap = false,
    this.progressFirestoreDocId,
    this.initialRegion,
    this.initialQubaChallengeCompleted = false,
    this.initialLastRegionChallengeCompleted = false,
    this.clearRecommendationTracking = false,
    this.hasSavedMapProgress = false,
    this.onManualPrimary,
  });

  final String catalogJourneyId;
  final String journeyTitle;
  final String landmarksJourneyId;
  final JourneyHowToPlayPresentation presentation;

  /// After a fresh payment the active-journey doc was deleted; create access + progress here, then open the map.
  final bool needsProgressBootstrap;

  /// Firestore `activeJourneys` document id when it may differ from [catalogJourneyId].
  final String? progressFirestoreDocId;
  final int? initialRegion;
  final bool initialQubaChallengeCompleted;
  final bool initialLastRegionChallengeCompleted;
  final bool clearRecommendationTracking;

  /// For [JourneyHowToPlayPresentation.manualFromPurchase]: whether the user already has map progress.
  final bool hasSavedMapProgress;

  /// For [manualFromPurchase] only: opens the map (or starts journey) without writing [hasSeenHowToPlay].
  final Future<void> Function(BuildContext navContext)? onManualPrimary;

  @override
  State<JourneyHowToPlayPage> createState() => _JourneyHowToPlayPageState();
}

class _JourneyHowToPlayPageState extends State<JourneyHowToPlayPage> {
  bool _busy = false;

  String _primaryLabel(AppLocalizations l10n) {
    switch (widget.presentation) {
      case JourneyHowToPlayPresentation.mandatoryFirstTime:
        return l10n.journeyPurchaseStartYourJourney;
      case JourneyHowToPlayPresentation.manualFromPurchase:
        return widget.hasSavedMapProgress
            ? l10n.journeyPurchaseContinueYourJourney
            : l10n.journeyPurchaseStartYourJourney;
    }
  }

  Future<void> _onPrimaryPressed() async {
    final l10n = AppLocalizations.of(context)!;

    if (widget.presentation == JourneyHowToPlayPresentation.manualFromPurchase) {
      final fn = widget.onManualPrimary;
      if (fn == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      setState(() => _busy = true);
      try {
        await fn(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(toUserFriendlyMessage(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    // Mandatory first-time: persist seen flag, then map.
    setState(() => _busy = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    var persistOk = true;
    try {
      if (widget.needsProgressBootstrap) {
        final journeyRepo = JourneyRepositoryFirebase(JourneyDataSource());
        final orderRepo = OrderRepositoryFirebase(OrderDataSource());
        final access = AccessService(journeyRepo: journeyRepo, orderRepo: orderRepo);
        await access.assertPaidForPlay(userId: uid, journeyId: widget.catalogJourneyId);
        await JourneyProgressDataSource().upsert(
          userId: uid,
          journeyId: widget.catalogJourneyId,
          journeyTitle: widget.journeyTitle,
          landmarksJourneyId: widget.landmarksJourneyId,
          catalogJourneyId: widget.catalogJourneyId,
          currentRegion: 1,
          qubaChallengeCompleted: false,
          lastRegionChallengeCompleted: false,
          hasSeenHowToPlay: true,
        );
      } else {
        final docId = widget.progressFirestoreDocId ?? widget.catalogJourneyId;
        await JourneyProgressDataSource().mergeHasSeenHowToPlay(
          userId: uid,
          journeyId: docId,
          value: true,
        );
      }
    } catch (_) {
      persistOk = false;
    }

    if (!mounted) return;
    setState(() => _busy = false);

    if (!persistOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.howToPlaySaveHintFailed)),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => JourneyMapScreen(
          journeyTitle: widget.journeyTitle,
          landmarksJourneyId: widget.landmarksJourneyId,
          catalogJourneyId: widget.catalogJourneyId,
          initialRegion: widget.initialRegion,
          initialQubaChallengeCompleted: widget.initialQubaChallengeCompleted,
          initialLastRegionChallengeCompleted: widget.initialLastRegionChallengeCompleted,
          clearRecommendationTracking: widget.clearRecommendationTracking,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.green,
      appBar: AppBar(
        title: Text(
          l10n.howToPlayAppBarTitle,
          style: const TextStyle(
            color: AppColors.brown,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.green,
        foregroundColor: AppColors.brown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.brown),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1,
                minHeight: 4,
                backgroundColor: AppColors.brown.withValues(alpha: 0.12),
                color: AppColors.orange.withValues(alpha: 0.85),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.howToPlayTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brown,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.howToPlaySubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.brown.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _HowToStepCard(
                    icon: Icons.map_rounded,
                    title: l10n.howToPlayStep1Title,
                    body: l10n.howToPlayStep1Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.explore_rounded,
                    title: l10n.howToPlayStep2Title,
                    body: l10n.howToPlayStep2Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.menu_book_rounded,
                    title: l10n.howToPlayStep3Title,
                    body: l10n.howToPlayStep3Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.photo_camera_rounded,
                    title: l10n.howToPlayStep4Title,
                    body: l10n.howToPlayStep4Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.extension_rounded,
                    title: l10n.howToPlayStep5Title,
                    body: l10n.howToPlayStep5Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.flag_rounded,
                    title: l10n.howToPlayStep6Title,
                    body: l10n.howToPlayStep6Body,
                  ),
                  _HowToStepCard(
                    icon: Icons.recommend_outlined,
                    title: l10n.howToPlayRecommendationsTitle,
                    body: l10n.howToPlayRecommendationsBody,
                  ),
                  _HowToStepCard(
                    icon: Icons.schedule_rounded,
                    title: l10n.howToPlayInactivityTitle,
                    body: l10n.howToPlayInactivityBody,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.beige,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, size: 22, color: AppColors.orange.withValues(alpha: 0.95)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.howToPlayTipFooter,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: AppColors.brown.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.paddingOf(context).bottom > 0 ? 8 : 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _onPrimaryPressed,
                  style: MapButtonStyles.secondaryFilled(
                    textStyle: MapTextStyles.buttonLabel.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.beige,
                    ),
                  ).copyWith(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.beige),
                        )
                      : Text(_primaryLabel(l10n)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToStepCard extends StatelessWidget {
  const _HowToStepCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.beige,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.brown.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.orange, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brown,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.brown.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
