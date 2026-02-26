/// Order payment lifecycle status.
enum OrderStatus {
  pendingPayment,
  paid,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  /// Firestore-safe string value (e.g. "PENDING_PAYMENT").
  String get value {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 'PENDING_PAYMENT';
      case OrderStatus.paid:
        return 'PAID';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static OrderStatus fromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'PENDING_PAYMENT':
        return OrderStatus.pendingPayment;
      case 'PAID':
        return OrderStatus.paid;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pendingPayment;
    }
  }
}

/// Order entity: links a user and a journey with amount and status.
class Order {
  final String? orderId;
  final String userId;
  final String journeyId;
  final double totalAmount;
  final String currency;
  final OrderStatus status;
  final DateTime? createdAt;

  Order({
    this.orderId,
    required this.userId,
    required this.journeyId,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'journeyId': journeyId,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status.value,
      'createdAt': createdAt,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map, {String? id}) {
    return Order(
      orderId: id,
      userId: map['userId'] as String? ?? '',
      journeyId: map['journeyId'] as String? ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'SAR',
      status: OrderStatusExtension.fromString(map['status'] as String?),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : null,
    );
  }
}
