import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/faq_item.dart';

class FaqDataSource {
  static const String collection = 'faqs';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live stream of all FAQ documents (order is not guaranteed by Firestore).
  Stream<List<FaqItem>> watchFaqs() {
    return _firestore.collection(collection).snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => FaqItem.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort(
          (a, b) => a.question.toLowerCase().compareTo(b.question.toLowerCase()),
        );
      return items;
    });
  }
}
