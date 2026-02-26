import '../model/order.dart';

/// Abstraction for persisting orders.
abstract class OrderRepository {
  /// Saves the order and returns the created order (with id and createdAt if set by backend).
  Future<Order> save(Order order);

  /// Fetches an order by document ID. Returns null if not found.
  Future<Order?> getById(String orderId);

  /// Updates order status. Returns the updated order.
  Future<Order> updateStatus(String orderId, OrderStatus status);

  /// Fetches the user's order for a journey (if any). Returns null if none.
  Future<Order?> getUserOrderForJourney(String userId, String journeyId);
}
