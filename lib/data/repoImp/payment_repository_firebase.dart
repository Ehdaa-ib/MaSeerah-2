import '../../model/payment.dart';
import '../../repository/payment_repo.dart';
import '../firebase/payment_data_source.dart';

class PaymentRepositoryFirebase implements PaymentRepository {
  final PaymentDataSource _dataSource;

  PaymentRepositoryFirebase(this._dataSource);

  @override
  Future<Payment> save(Payment payment) async {
    return _dataSource.create(payment);
  }

  @override
  Future<Payment?> getById(String paymentId) async {
    return _dataSource.getById(paymentId);
  }

  @override
  Future<Payment?> getByGatewayTransactionId(String gatewayTransactionId) async {
    return _dataSource.getByGatewayTransactionId(gatewayTransactionId);
  }

  @override
  Future<Payment?> getLastPaymentForOrder(String orderId) async {
    return _dataSource.getLastPaymentForOrder(orderId);
  }

  @override
  Future<Payment> updateStatus(String paymentId, PaymentStatus status) async {
    return _dataSource.updateStatus(paymentId, status);
  }

  @override
  Future<Payment> updateStatusAndGatewayId(
    String paymentId,
    PaymentStatus status,
    String? gatewayTransactionId,
  ) async {
    return _dataSource.updateStatusAndGatewayId(
      paymentId,
      status,
      gatewayTransactionId,
    );
  }
}
