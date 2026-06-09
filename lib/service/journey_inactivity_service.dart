import '../data/firebase/journey_progress_data_source.dart';
import '../data/firebase/journey_repurchase_gate_data_source.dart';

/// FR-19: end ongoing journeys after prolonged inactivity (72 hours).
class JourneyInactivityService {
  JourneyInactivityService({
    JourneyProgressDataSource? progressDs,
    JourneyRepurchaseGateDataSource? repurchaseGateDs,
  }) : _progressDs = progressDs ?? JourneyProgressDataSource(),
       _repurchaseGateDs =
           repurchaseGateDs ?? JourneyRepurchaseGateDataSource();

  final JourneyProgressDataSource _progressDs;
  final JourneyRepurchaseGateDataSource _repurchaseGateDs;

  /// Inactivity window before an active journey is terminated.
  static const Duration inactivityLimit = Duration(hours: 72);

  bool isInactive(ActiveJourneyProgress progress) {
    if (progress.updatedAtMillis <= 0) return false;
    final lastActive = DateTime.fromMillisecondsSinceEpoch(
      progress.updatedAtMillis,
    );
    return DateTime.now().difference(lastActive) >= inactivityLimit;
  }

  Future<bool> terminateIfInactive({
    required String userId,
    required ActiveJourneyProgress progress,
  }) async {
    if (!isInactive(progress)) return false;
    await _progressDs.delete(
      userId: userId,
      journeyId: progress.firestoreDocId,
    );
    final gateId = (progress.catalogJourneyId?.trim().isNotEmpty ?? false)
        ? progress.catalogJourneyId!.trim()
        : progress.journeyId.trim();
    if (gateId.isNotEmpty) {
      try {
        await _repurchaseGateDs.setRequiresRepurchase(
          userId: userId,
          journeyId: gateId,
        );
      } catch (_) {}
    }
    return true;
  }

  /// Returns progress only when still active; deletes and returns null if inactive.
  Future<ActiveJourneyProgress?> resolveActiveProgress({
    required String userId,
    required String journeyId,
  }) async {
    final progress = await _progressDs.getUserJourneyProgress(
      userId: userId,
      journeyId: journeyId,
    );
    if (progress == null) return null;
    if (await terminateIfInactive(userId: userId, progress: progress)) {
      return null;
    }
    return progress;
  }

  /// Deletes inactive docs; returns journeys that remain active.
  Future<List<ActiveJourneyProgress>> purgeInactiveForUser(
    String userId,
  ) async {
    final all = await _progressDs.listAll(userId: userId);
    final remaining = <ActiveJourneyProgress>[];
    for (final p in all) {
      if (await terminateIfInactive(userId: userId, progress: p)) {
        continue;
      }
      remaining.add(p);
    }
    return remaining;
  }
}
