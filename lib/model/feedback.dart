import 'package:cloud_firestore/cloud_firestore.dart';

/// Single admin reply stored on a `feedback/{id}` document (`adminResponses` array).
class AdminFeedbackReply {
  final String message;
  final String? adminEmail;
  final DateTime? respondedAt;

  const AdminFeedbackReply({
    required this.message,
    this.adminEmail,
    this.respondedAt,
  });

  factory AdminFeedbackReply.fromMap(Map<String, dynamic> map) {
    final ts = map['respondedAt'] ?? map['createdAt'];
    return AdminFeedbackReply(
      message: (map['message'] as String?)?.trim() ?? '',
      adminEmail: (map['adminEmail'] as String?)?.trim().isNotEmpty == true
          ? (map['adminEmail'] as String).trim()
          : null,
      respondedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

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
  final List<AdminFeedbackReply> adminResponses;

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
    this.adminResponses = const [],
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

  static List<AdminFeedbackReply> _adminResponsesFromMap(Map<String, dynamic> map) {
    final raw = map['adminResponses'];
    if (raw is! List) return const [];
    final out = <AdminFeedbackReply>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(AdminFeedbackReply.fromMap(e));
      } else if (e is Map) {
        out.add(AdminFeedbackReply.fromMap(Map<String, dynamic>.from(e)));
      }
    }
    return out;
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
      adminResponses: _adminResponsesFromMap(map),
    );
  }
}

