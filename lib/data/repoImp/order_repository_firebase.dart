import '../../model/order.dart';
import '../../repository/order_repo.dart';
import '../firebase/order_data_source.dart';

class OrderRepositoryFirebase implements OrderRepository {
  final OrderDataSource _dataSource;

  OrderRepositoryFirebase(this._dataSource);

  @override
  Future<Order> save(Order order) async {
    return _dataSource.create(order);
  }

  @override
  Future<Order?> getById(String orderId) async {
    return _dataSource.getById(orderId);
  }

  @override
  Future<Order> updateStatus(String orderId, OrderStatus status) async {
    return _dataSource.updateStatus(orderId, status);
  }

  @override
  Future<Order?> getUserOrderForJourney(String userId, String journeyId) async {
    return _dataSource.getUserOrderForJourney(userId, journeyId);
  }
}
