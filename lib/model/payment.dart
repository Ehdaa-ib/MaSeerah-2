/// Payment processing status.
enum PaymentStatus {
  processing,
  success,
  failed,
  cancelled,
}

extension PaymentStatusExtension on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.processing:
        return 'PROCESSING';
      case PaymentStatus.success:
        return 'SUCCESS';
      case PaymentStatus.failed:
        return 'FAILED';
      case PaymentStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static PaymentStatus fromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'PROCESSING':
        return PaymentStatus.processing;
      case 'SUCCESS':
        return PaymentStatus.success;
      case 'FAILED':
        return PaymentStatus.failed;
      case 'CANCELLED':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.processing;
    }
  }
}

/// Supported payment methods.
enum PaymentMethod {
  card,
  mada,
  applePay,
}

extension PaymentMethodExtension on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.card:
        return 'CARD';
      case PaymentMethod.mada:
        return 'MADA';
      case PaymentMethod.applePay:
        return 'APPLE_PAY';
    }
  }

  static PaymentMethod fromString(String? v) {
    switch (v?.toUpperCase()) {
      case 'CARD':
        return PaymentMethod.card;
      case 'MADA':
        return PaymentMethod.mada;
      case 'APPLE_PAY':
        return PaymentMethod.applePay;
      default:
        return PaymentMethod.card;
    }
  }
}

/// Payment record linked to an order and Moyasar gateway.
class Payment {
  final String? paymentId;
  final String orderId;
  final double amount;
  final String currency;
  final PaymentMethod paymentMethod;
  final PaymentStatus status;
  final String? gatewayTransactionId;
  final DateTime? createdAt;

  Payment({
    this.paymentId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    this.gatewayTransactionId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'amount': amount,
      'currency': currency,
      'paymentMethod': paymentMethod.value,
      'status': status.value,
      'gatewayTransactionId': gatewayTransactionId,
      'createdAt': createdAt,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map, {String? id}) {
    return Payment(
      paymentId: id,
      orderId: map['orderId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'SAR',
      paymentMethod: PaymentMethodExtension.fromString(map['paymentMethod'] as String?),
      status: PaymentStatusExtension.fromString(map['status'] as String?),
      gatewayTransactionId: map['gatewayTransactionId'] as String?,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : null,
    );
  }

  Payment copyWith({
    String? paymentId,
    String? orderId,
    double? amount,
    String? currency,
    PaymentMethod? paymentMethod,
    PaymentStatus? status,
    String? gatewayTransactionId,
    DateTime? createdAt,
  }) {
    return Payment(
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      gatewayTransactionId: gatewayTransactionId ?? this.gatewayTransactionId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
