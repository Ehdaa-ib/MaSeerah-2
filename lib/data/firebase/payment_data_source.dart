import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/payment.dart' as app;

class PaymentDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'payments';

  Future<app.Payment> create(app.Payment payment) async {
    final ref = _firestore.collection(_collection).doc();
    final data = payment.toMap();
    data['createdAt'] = payment.createdAt != null
        ? Timestamp.fromDate(payment.createdAt!)
        : FieldValue.serverTimestamp();
    await ref.set(data);
    final doc = await ref.get();
    final saved = Map<String, dynamic>.from(doc.data()!);
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Payment.fromMap(saved, id: doc.id);
  }

  Future<app.Payment?> getById(String paymentId) async {
    final doc = await _firestore.collection(_collection).doc(paymentId).get();
    if (!doc.exists || doc.data() == null) return null;
    final saved = Map<String, dynamic>.from(doc.data()!);
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Payment.fromMap(saved, id: doc.id);
  }

  Future<app.Payment?> getByGatewayTransactionId(String id) async {
    final q = await _firestore
        .collection(_collection)
        .where('gatewayTransactionId', isEqualTo: id)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final saved = Map<String, dynamic>.from(doc.data());
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Payment.fromMap(saved, id: doc.id);
  }

  Future<app.Payment?> getLastPaymentForOrder(String orderId) async {
    final q = await _firestore
        .collection(_collection)
        .where('orderId', isEqualTo: orderId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final saved = Map<String, dynamic>.from(doc.data());
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Payment.fromMap(saved, id: doc.id);
  }

  Future<app.Payment> updateStatus(String paymentId, app.PaymentStatus status) async {
    await _firestore.collection(_collection).doc(paymentId).update({'status': status.value});
    final p = await getById(paymentId);
    if (p == null) throw Exception('Payment not found');
    return p.copyWith(status: status);
  }

  Future<app.Payment> updateStatusAndGatewayId(
    String paymentId,
    app.PaymentStatus status,
    String? gatewayTransactionId,
  ) async {
    final updates = <String, dynamic>{'status': status.value};
    if (gatewayTransactionId != null) updates['gatewayTransactionId'] = gatewayTransactionId;
    await _firestore.collection(_collection).doc(paymentId).update(updates);
    final p = await getById(paymentId);
    if (p == null) throw Exception('Payment not found');
    return p.copyWith(status: status, gatewayTransactionId: gatewayTransactionId ?? p.gatewayTransactionId);
  }
}
