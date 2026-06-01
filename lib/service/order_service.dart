import '../model/order.dart';
import '../repository/journey_repo.dart';
import '../repository/order_repo.dart';

/// Application service for order use cases. Keeps business logic out of UI/controllers.
class OrderService {
  final JourneyRepository _journeyRepo;
  final OrderRepository _orderRepo;

  OrderService({
    required JourneyRepository journeyRepo,
    required OrderRepository orderRepo,
  })  : _journeyRepo = journeyRepo,
        _orderRepo = orderRepo;

  /// Creates a new order for the given user and journey.
  ///
  /// 1) Validates that the journey exists.
  /// 2) Retrieves the journey price.
  /// 3) Calculates total amount (currently equal to journey price).
  /// 4) Rejects free journeys (price = 0).
  /// 5) Creates an order with status [OrderStatus.pendingPayment], currency SAR, and createdAt.
  /// 6) Persists and returns the created order.
  ///
  /// Throws if the journey does not exist or if the journey is free.
  Future<Order> createOrder({
    required String userId,
    required String journeyId,
    double? knownPrice,
  }) async {
    // 1) Basic validation: non-empty ids
    if (userId.trim().isEmpty) {
      throw Exception('User ID is required.');
    }
    if (journeyId.trim().isEmpty) {
      throw Exception('Journey ID is required.');
    }

    // 2) Price from caller when already on journey details (skips an extra read).
    late final double price;
    if (knownPrice != null && knownPrice > 0) {
      price = knownPrice;
    } else {
      final journey = await _journeyRepo.getById(journeyId.trim());
      if (journey == null) {
        throw Exception('Journey not found.');
      }
      price = journey.price;
      if (price <= 0) {
        throw Exception('Cannot create an order for a free journey.');
      }
    }

    // 3) Calculate total amount (for now equal to journey price)
    final totalAmount = price;

    // 5) Build order: status PENDING_PAYMENT, currency SAR, createdAt
    final now = DateTime.now();
    final order = Order(
      userId: userId.trim(),
      journeyId: journeyId.trim(),
      totalAmount: totalAmount,
      currency: 'SAR',
      status: OrderStatus.pendingPayment,
      createdAt: now,
    );

    // 6) Create and persist the order, then return the saved record
    final saved = await _orderRepo.save(order);
    return saved;
  }

  /// Sets order status to PAID. Called only after payment success.
  Future<Order> confirmOrder(String orderId) async {
    if (orderId.trim().isEmpty) throw Exception('Order ID is required.');
    final order = await _orderRepo.getById(orderId.trim());
    if (order == null) throw Exception('Order not found.');
    return _orderRepo.updateStatus(orderId.trim(), OrderStatus.paid);
  }

  /// Sets order status to CANCELLED. Used if user cancels before paying.
  Future<Order> cancelOrder(String orderId) async {
    if (orderId.trim().isEmpty) throw Exception('Order ID is required.');
    final order = await _orderRepo.getById(orderId.trim());
    if (order == null) throw Exception('Order not found.');
    return _orderRepo.updateStatus(orderId.trim(), OrderStatus.cancelled);
  }

  /// Fetches existing order for user+journey. Used when checking access.
  Future<Order?> getUserOrderForJourney({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return null;
    return _orderRepo.getUserOrderForJourney(userId.trim(), journeyId.trim());
  }

  Future<Order?> getPendingOrderForJourney({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return null;
    return _orderRepo.getPendingOrderForJourney(userId.trim(), journeyId.trim());
  }

  /// Pending order for checkout, or a new one when the latest order is already paid/cancelled.
  Future<Order> getOrCreateCheckoutOrder({
    required String userId,
    required String journeyId,
    double? knownPrice,
    bool forceNew = false,
  }) async {
    if (!forceNew) {
      final pending = await getPendingOrderForJourney(
        userId: userId,
        journeyId: journeyId,
      );
      if (pending != null) return pending;
    }
    return createOrder(
      userId: userId,
      journeyId: journeyId,
      knownPrice: knownPrice,
    );
  }

  /// True if the user has ever completed payment for this journey (any paid order).
  Future<bool> userHasPaidForJourney({
    required String userId,
    required String journeyId,
  }) async {
    if (userId.trim().isEmpty || journeyId.trim().isEmpty) return false;
    return _orderRepo.hasPaidOrderForJourney(userId.trim(), journeyId.trim());
  }
}
