/// Journey entity for display and pricing when creating orders.
class Journey {
  final String journeyId;
  final String name;
  final double price;

  Journey({
    required this.journeyId,
    required this.name,
    required this.price,
  });

  factory Journey.fromMap(Map<String, dynamic> map, {String? id}) {
    return Journey(
      journeyId: id ?? map['journeyId'] as String? ?? '',
      name: map['name'] as String? ?? 'Journey',
      price: (map['price'] as num?)?.toDouble() ?? 0,
    );
  }
}
