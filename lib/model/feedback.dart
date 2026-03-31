import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackEntry {
  final String userId;
  final String journeyId;
  final DateTime? createdAt;
  final int overallRating;
  final int contentRating;
  final int recommendationRating;
  final int challengeRating;
  final String overallComment;
  final List<String> photos;

  FeedbackEntry({
    required this.userId,
    required this.journeyId,
    this.createdAt,
    required this.overallRating,
    required this.contentRating,
    required this.recommendationRating,
    required this.challengeRating,
    required this.overallComment,
    required this.photos,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'journeyId': journeyId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'overallRating': overallRating,
      'contentRating': contentRating,
      'recommendationRating': recommendationRating,
      'challengeRating': challengeRating,
      'overallComment': overallComment,
      'photos': photos,
    };
  }

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    final ts = map['createdAt'];
    return FeedbackEntry(
      userId: (map['userId'] as String?) ?? '',
      journeyId: (map['journeyId'] as String?) ?? '',
      createdAt: ts is Timestamp ? ts.toDate() : null,
      overallRating: (map['overallRating'] as num?)?.toInt() ?? 0,
      contentRating: (map['contentRating'] as num?)?.toInt() ?? 0,
      recommendationRating: (map['recommendationRating'] as num?)?.toInt() ?? 0,
      challengeRating: (map['challengeRating'] as num?)?.toInt() ?? 0,
      overallComment: (map['overallComment'] as String?) ?? '',
      photos: (map['photos'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

