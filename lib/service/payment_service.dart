import '../core/moyasar_config.dart';
import '../model/order.dart';
import '../model/payment.dart';
import '../repository/order_repo.dart';
import '../repository/payment_repo.dart';

/// Service for Moyasar payment integration and payment lifecycle.
class PaymentService {
  final OrderRepository _orderRepo;
  final PaymentRepository _paymentRepo;

  PaymentService({
    required OrderRepository orderRepo,
    required PaymentRepository paymentRepo,
  })  : _orderRepo = orderRepo,
        _paymentRepo = paymentRepo;

  static const List<PaymentMethod> _allowedMethods = [
    PaymentMethod.card,
    PaymentMethod.mada,
    PaymentMethod.applePay,
  ];

  /// Validates order exists, is PENDING_PAYMENT, creates Payment record (PROCESSING),
  /// returns payment session data for Moyasar (amount in halalas, keys).
  Future<Payment> processPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
  }) async {
    if (orderId.trim().isEmpty) throw Exception('Order ID is required.');
    if (!_allowedMethods.contains(paymentMethod)) {
      throw Exception('Payment method not allowed.');
    }

    final order = await _orderRepo.getById(orderId.trim());
    if (order == null) throw Exception('Order not found.');
    if (order.status != OrderStatus.pendingPayment) {
      throw Exception('Order is not pending payment.');
    }

    final payment = Payment(
      orderId: order.orderId!,
      amount: order.totalAmount,
      currency: order.currency,
      paymentMethod: paymentMethod,
      status: PaymentStatus.processing,
      createdAt: DateTime.now(),
    );
    final saved = await _paymentRepo.save(payment);
    return saved;
  }

  /// Simulates webhook: finds payment by gateway transaction ID,
  /// updates status, and confirms order if paid.
  Future<void> handlePaymentWebhook({
    required String gatewayTransactionId,
    required bool paid,
  }) async {
    final payment = await _paymentRepo.getByGatewayTransactionId(gatewayTransactionId);
    if (payment == null) throw Exception('Payment not found.');

    if (paid) {
      await _paymentRepo.updateStatus(payment.paymentId!, PaymentStatus.success);
      await _orderRepo.updateStatus(payment.orderId, OrderStatus.paid);
    } else {
      await _paymentRepo.updateStatus(payment.paymentId!, PaymentStatus.failed);
    }
  }

  /// Call after Moyasar SDK reports success. Updates payment and confirms order.
  Future<void> handlePaymentSuccess({
    required String paymentId,
    required String? gatewayTransactionId,
  }) async {
    final payment = await _paymentRepo.getById(paymentId);
    if (payment == null) throw Exception('Payment not found.');
    await _paymentRepo.updateStatusAndGatewayId(
      paymentId,
      PaymentStatus.success,
      gatewayTransactionId,
    );
    await _orderRepo.updateStatus(payment.orderId, OrderStatus.paid);
  }

  /// Call after Moyasar SDK reports failure.
  Future<void> handlePaymentFailed({required String paymentId}) async {
    final payment = await _paymentRepo.getById(paymentId);
    if (payment == null) throw Exception('Payment not found.');
    await _paymentRepo.updateStatus(paymentId, PaymentStatus.failed);
  }

  /// Retry payment only if last payment is FAILED or CANCELLED.
  Future<Payment> retryPayment({
    required String orderId,
    required PaymentMethod paymentMethod,
  }) async {
    final last = await _paymentRepo.getLastPaymentForOrder(orderId);
    if (last != null &&
        last.status != PaymentStatus.failed &&
        last.status != PaymentStatus.cancelled) {
      throw Exception('Retry only allowed when last payment is FAILED or CANCELLED.');
    }
    return processPayment(orderId: orderId, paymentMethod: paymentMethod);
  }

  Future<Payment?> getPaymentStatus(String paymentId) async {
    return _paymentRepo.getById(paymentId);
  }

  String get secretKey => MoyasarConfig.secretKey;
  String get publishableKey => MoyasarConfig.publishableKey;
}
