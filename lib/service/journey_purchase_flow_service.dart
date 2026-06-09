import '../data/firebase/journey_progress_data_source.dart';
import 'journey_user_status_service.dart';

/// Primary action on the journey purchase / details screen.
enum JourneyPurchasePrimaryAction {
  signIn,
  loading,
  purchase,
  start,
  continueJourney,
  giveFeedback,
  viewHistory,
}

/// Resolved UI state from Firestore-backed journey lifecycle rules.
class JourneyPurchaseUiState {
  const JourneyPurchaseUiState({
    required this.action,
    required this.status,
    this.progress,
    this.showHowToPlayInfo = false,
  });

  final JourneyPurchasePrimaryAction action;
  final JourneyUserStatusResult status;
  final ActiveJourneyProgress? progress;
  final bool showHowToPlayInfo;

  bool get isPurchasedEntitled =>
      action == JourneyPurchasePrimaryAction.start ||
      action == JourneyPurchasePrimaryAction.continueJourney ||
      action == JourneyPurchasePrimaryAction.giveFeedback ||
      showHowToPlayInfo;
}

/// Maps paid access + [JourneyUserStatusService] output to purchase-screen CTAs.
class JourneyPurchaseFlowService {
  JourneyPurchaseFlowService({JourneyUserStatusService? statusService})
    : _statusService = statusService ?? JourneyUserStatusService();

  final JourneyUserStatusService _statusService;

  Future<JourneyPurchaseUiState> resolve({
    required String userId,
    required String journeyId,
    required double journeyPrice,
    required bool hasPaidOrder,
    bool isLoading = false,
  }) async {
    if (isLoading) {
      return JourneyPurchaseUiState(
        action: JourneyPurchasePrimaryAction.loading,
        status: JourneyUserStatusResult(
          status: JourneyUserStatus.loading,
          progress: null,
          awaitingFeedback: false,
          requiresRepurchase: false,
        ),
      );
    }

    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) {
      return JourneyPurchaseUiState(
        action: JourneyPurchasePrimaryAction.signIn,
        status: JourneyUserStatusResult(
          status: JourneyUserStatus.notStarted,
          progress: null,
          awaitingFeedback: false,
          requiresRepurchase: false,
        ),
      );
    }

    final status = await _statusService.getStatus(userId: uid, journeyId: jid);
    return resolveFromStatus(
      journeyPrice: journeyPrice,
      hasPaidOrder: hasPaidOrder,
      status: status,
    );
  }

  /// Same rules as [resolve] but without extra Firestore reads (use after [_loadUserAccess]).
  JourneyPurchaseUiState resolveFromStatus({
    required double journeyPrice,
    required bool hasPaidOrder,
    required JourneyUserStatusResult status,
  }) {
    final isFree = journeyPrice <= 0;
    final entitled = isFree || (hasPaidOrder && !status.requiresRepurchase);

    if (status.progress != null) {
      return JourneyPurchaseUiState(
        action: JourneyPurchasePrimaryAction.continueJourney,
        status: status,
        progress: status.progress,
        showHowToPlayInfo: entitled,
      );
    }

    // Finished playthroughs (with or without feedback) return to purchase — not Continue.
    if (status.requiresRepurchase ||
        status.status == JourneyUserStatus.completed) {
      return JourneyPurchaseUiState(
        action: JourneyPurchasePrimaryAction.purchase,
        status: status,
      );
    }

    if (entitled) {
      return JourneyPurchaseUiState(
        action: JourneyPurchasePrimaryAction.start,
        status: status,
        showHowToPlayInfo: true,
      );
    }

    return JourneyPurchaseUiState(
      action: JourneyPurchasePrimaryAction.purchase,
      status: status,
    );
  }

  /// Builds [JourneyUserStatusResult] from data already loaded on the purchase screen.
  static JourneyUserStatusResult statusFromSnapshot({
    required ActiveJourneyProgress? progress,
    required bool requiresRepurchase,
    required bool journeyCompleted,
    required bool awaitingFeedback,
  }) {
    if (progress != null) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.active,
        progress: progress,
        awaitingFeedback: false,
        requiresRepurchase: false,
      );
    }
    if (requiresRepurchase) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.completed,
        progress: null,
        awaitingFeedback: false,
        requiresRepurchase: true,
      );
    }
    if (journeyCompleted) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.completed,
        progress: null,
        awaitingFeedback: awaitingFeedback,
        requiresRepurchase: false,
      );
    }
    return JourneyUserStatusResult(
      status: JourneyUserStatus.notStarted,
      progress: null,
      awaitingFeedback: false,
      requiresRepurchase: false,
    );
  }
}
