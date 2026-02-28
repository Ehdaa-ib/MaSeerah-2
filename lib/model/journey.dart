/// Journey entity for display and pricing when creating orders.
class Journey {
  final String journeyId;
  final String name;
  final double price;
  final String? description;
  final String? startPoint;
  final String? endPoint;
  final String? stops;
  final String? estimatedDuration;
  final String? distance;
  final String? goodToKnow;
  final String? languages;
  final String? city;

  Journey({
    required this.journeyId,
    required this.name,
    required this.price,
    this.description,
    this.startPoint,
    this.endPoint,
    this.stops,
    this.estimatedDuration,
    this.distance,
    this.goodToKnow,
    this.languages,
    this.city,
  });

  factory Journey.fromMap(Map<String, dynamic> map, {String? id}) {
    return Journey(
      journeyId: id ?? map['journeyId'] as String? ?? '',
      name: map['name'] as String? ?? 'Journey',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      description: map['description'] as String?,
      startPoint: map['startPoint'] as String?,
      endPoint: map['endPoint'] as String?,
      stops: map['stops'] as String?,
      estimatedDuration: map['estimatedDuration'] as String?,
      distance: map['distance'] as String?,
      goodToKnow: map['goodToKnow'] as String?,
      languages: map['languages'] as String?,
      city: map['city'] as String?,
    );
  }
}
