/// Single FAQ document from Firestore `faqs` collection.
class FaqItem {
  final String id;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromFirestore(String id, Map<String, dynamic> data) {
    return FaqItem(
      id: id,
      question: data['question'] is String ? data['question'] as String : '',
      answer: data['answer'] is String ? data['answer'] as String : '',
    );
  }
}
