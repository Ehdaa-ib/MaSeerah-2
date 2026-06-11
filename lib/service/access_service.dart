import '../data/firebase/journey_completion_data_source.dart';
import '../data/firebase/journey_repurchase_gate_data_source.dart';
import '../repository/journey_repo.dart';
import '../repository/order_repo.dart';

/// Access control for journeys. Free journeys allowed; paid journeys require PAID order.
class AccessService {
  final JourneyRepository _journeyRepo;
  final OrderRepository _orderRepo;
  final JourneyCompletionDataSource _completionDs;
  final JourneyRepurchaseGateDataSource _repurchaseGateDs;

  AccessService({
    required JourneyRepository journeyRepo,
    required OrderRepository orderRepo,
    JourneyCompletionDataSource? completionDs,
    JourneyRepurchaseGateDataSource? repurchaseGateDs,
  }) : _journeyRepo = journeyRepo,
       _orderRepo = orderRepo,
       _completionDs = completionDs ?? JourneyCompletionDataSource(),
       _repurchaseGateDs =
           repurchaseGateDs ?? JourneyRepurchaseGateDataSource();

  /// Paid access for a new play session (purchase screen → Start). Does not block on completion;
  /// the UI routes completed runs to feedback or Unlock instead.
  Future<void> assertPaidForPlay({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty) throw Exception('User ID is required.');
    if (journeyId.trim().isEmpty) throw Exception('Journey ID is required.');

    final journey = await _journeyRepo.getById(journeyId.trim());
    if (journey == null) throw Exception('Journey not found.');

    if (journey.price <= 0) return;

    final hasPaid = await _orderRepo.hasPaidOrderForJourney(
      userId.trim(),
      journeyId.trim(),
    );
    if (!hasPaid) throw Exception('Payment required.');

    if (await _repurchaseGateDs.requiresNewPurchase(
      userId: userId.trim(),
      journeyId: journeyId.trim(),
    )) {
      throw Exception('Purchase this journey again to start.');
    }
  }

  /// Map entry check (resume or mid-run). Requires payment and no repurchase gate.
  Future<void> startJourney({
    required String userId,
    required String journeyId,
  }) async {
    await assertPaidForPlay(userId: userId, journeyId: journeyId);

    final completed = await _completionDs.isCompleted(
      userId: userId.trim(),
      journeyId: journeyId.trim(),
    );
    if (completed) {
      throw Exception('Pay again to start this journey.');
    }
  }
}
