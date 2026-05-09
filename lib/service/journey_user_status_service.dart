import '../data/firebase/journey_completion_data_source.dart';
import '../data/firebase/journey_progress_data_source.dart';
import '../data/firebase/journey_repurchase_gate_data_source.dart';

enum JourneyUserStatus {
  loading,
  notStarted,
  active,
  completed,
}

class JourneyUserStatusResult {
  JourneyUserStatusResult({
    required this.status,
    required this.progress,
    required this.awaitingFeedback,
    required this.requiresRepurchase,
  });

  final JourneyUserStatus status;
  final ActiveJourneyProgress? progress;
  final bool awaitingFeedback;
  final bool requiresRepurchase;
}

/// Single source of truth for user+journey state.
///
/// - `active` is driven by `users/{uid}/activeJourneys/{journeyId}` (same as Active Journeys tab).
/// - `completed` is driven by completion/repurchase gate.
class JourneyUserStatusService {
  JourneyUserStatusService({
    JourneyProgressDataSource? progressDs,
    JourneyCompletionDataSource? completionDs,
    JourneyRepurchaseGateDataSource? repurchaseGateDs,
  })  : _progressDs = progressDs ?? JourneyProgressDataSource(),
        _completionDs = completionDs ?? JourneyCompletionDataSource(),
        _repurchaseGateDs = repurchaseGateDs ?? JourneyRepurchaseGateDataSource();

  final JourneyProgressDataSource _progressDs;
  final JourneyCompletionDataSource _completionDs;
  final JourneyRepurchaseGateDataSource _repurchaseGateDs;

  Future<JourneyUserStatusResult> getStatus({
    required String userId,
    required String journeyId,
  }) async {
    final uid = userId.trim();
    final jid = journeyId.trim();
    if (uid.isEmpty || jid.isEmpty) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.notStarted,
        progress: null,
        awaitingFeedback: false,
        requiresRepurchase: false,
      );
    }

    // IMPORTANT: progress is the primary "continue" signal and should not depend on orders.
    final progress = await _progressDs.getUserJourneyProgress(userId: uid, journeyId: jid);
    if (progress != null) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.active,
        progress: progress,
        awaitingFeedback: false,
        requiresRepurchase: false,
      );
    }

    // After feedback, we require a new purchase.
    final requiresRepurchase = await _repurchaseGateDs.requiresNewPurchase(userId: uid, journeyId: jid);
    if (requiresRepurchase) {
      return JourneyUserStatusResult(
        status: JourneyUserStatus.completed,
        progress: null,
        awaitingFeedback: false,
        requiresRepurchase: true,
      );
    }

    final completed = await _completionDs.isCompleted(userId: uid, journeyId: jid);
    if (completed) {
      final awaitingFeedback = await _completionDs.isAwaitingFeedback(userId: uid, journeyId: jid);
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

