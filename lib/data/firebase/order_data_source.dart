import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/order.dart' as app;

/// Firestore access for orders collection.
class OrderDataSource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'orders';

  Future<app.Order> create(app.Order order) async {
    final ref = _firestore.collection(_collection).doc();
    final data = order.toMap();
    data['createdAt'] = order.createdAt != null
        ? Timestamp.fromDate(order.createdAt!)
        : FieldValue.serverTimestamp();
    await ref.set(data);
    final doc = await ref.get();
    final saved = Map<String, dynamic>.from(doc.data()!);
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Order.fromMap(saved, id: doc.id);
  }

  Future<app.Order?> getById(String orderId) async {
    final doc = await _firestore.collection(_collection).doc(orderId).get();
    if (!doc.exists || doc.data() == null) return null;
    final saved = Map<String, dynamic>.from(doc.data()!);
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Order.fromMap(saved, id: doc.id);
  }

  Future<app.Order> updateStatus(String orderId, app.OrderStatus status) async {
    await _firestore.collection(_collection).doc(orderId).update({'status': status.value});
    final order = await getById(orderId);
    if (order == null) throw Exception('Order not found');
    return app.Order(
      orderId: order.orderId,
      userId: order.userId,
      journeyId: order.journeyId,
      totalAmount: order.totalAmount,
      currency: order.currency,
      status: status,
      createdAt: order.createdAt,
    );
  }

  Future<app.Order?> getUserOrderForJourney(String userId, String journeyId) async {
    final q = await _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .where('journeyId', isEqualTo: journeyId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    final saved = Map<String, dynamic>.from(doc.data());
    if (saved['createdAt'] != null && saved['createdAt'] is Timestamp) {
      saved['createdAt'] = (saved['createdAt'] as Timestamp).toDate();
    }
    return app.Order.fromMap(saved, id: doc.id);
  }
}
 