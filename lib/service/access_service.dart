import '../model/order.dart';
import '../repository/journey_repo.dart';
import '../repository/order_repo.dart';

/// Access control for journeys. Free journeys allowed; paid journeys require PAID order.
class AccessService {
  final JourneyRepository _journeyRepo;
  final OrderRepository _orderRepo;

  AccessService({
    required JourneyRepository journeyRepo,
    required OrderRepository orderRepo,
  })  : _journeyRepo = journeyRepo,
        _orderRepo = orderRepo;

  /// If journey is free → allow. If paid → require Order.status == PAID, else reject.
  Future<void> startJourney({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty) throw Exception('User ID is required.');
    if (journeyId.trim().isEmpty) throw Exception('Journey ID is required.');

    final journey = await _journeyRepo.getById(journeyId.trim());
    if (journey == null) throw Exception('Journey not found.');

    // Free journey → allow
    if (journey.price <= 0) return;

    // Paid journey → check order is PAID
    final order = await _orderRepo.getUserOrderForJourney(userId.trim(), journeyId.trim());
    if (order == null) throw Exception('Payment required.');
    if (order.status != OrderStatus.paid) {
      throw Exception('Payment required.');
    }
  }
}
