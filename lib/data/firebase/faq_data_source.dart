import 'package:cloud_firestore/cloud_firestore.dart';

import '../../model/faq_item.dart';

class FaqDataSource {
  static const String collection = 'faqs';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live stream of all FAQ documents, ordered by the `order` field.
  Stream<List<FaqItem>> watchFaqs() {
    return _firestore.collection(collection).orderBy('order').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => FaqItem.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}
