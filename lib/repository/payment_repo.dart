import '../model/payment.dart';

abstract class PaymentRepository {
  Future<Payment> save(Payment payment);

  Future<Payment?> getById(String paymentId);

  Future<Payment?> getByGatewayTransactionId(String gatewayTransactionId);

  Future<Payment?> getLastPaymentForOrder(String orderId);

  Future<Payment> updateStatus(String paymentId, PaymentStatus status);

  Future<Payment> updateStatusAndGatewayId(
    String paymentId,
    PaymentStatus status,
    String? gatewayTransactionId,
  );
}
