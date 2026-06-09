import 'package:cloud_firestore/cloud_firestore.dart';

/// Landmark photo/video memory saved during a journey (`users/{uid}/journeyHistory/...`).
class LandmarkMemory {
  LandmarkMemory({
    required this.id,
    required this.journeyId,
    required this.journeyTitle,
    required this.landmarkId,
    required this.landmarkTitle,
    required this.landmarkOrder,
    required this.mediaUrl,
    required this.mediaType,
    required this.storagePath,
    this.userJourneyId,
    this.source,
    this.createdAt,
  });

  final String id;
  final String journeyId;
  final String? userJourneyId;
  final String journeyTitle;
  final String landmarkId;
  final String landmarkTitle;
  final int landmarkOrder;
  final String mediaUrl;
  final String mediaType;
  final String storagePath;
  final String? source;
  final DateTime? createdAt;

  bool get isVideo => mediaType == 'video';

  static LandmarkMemory? fromDoc(String id, Map<String, dynamic> d) {
    final url =
        (d['mediaUrl'] as String?)?.trim() ??
        (d['imageUrl'] as String?)?.trim();
    if (url == null || url.isEmpty) return null;
    final order = _readInt(d['landmarkOrder']) ?? 0;
    final created = d['createdAt'];
    DateTime? createdAt;
    if (created is Timestamp) createdAt = created.toDate();
    return LandmarkMemory(
      id: id,
      journeyId: (d['journeyId'] as String?)?.trim() ?? '',
      userJourneyId:
          ((d['userJourneyId'] as String?) ??
                  (d['journeyHistoryId'] as String?))
              ?.trim(),
      journeyTitle: (d['journeyTitle'] as String?)?.trim() ?? 'Journey',
      landmarkId: (d['landmarkId'] as String?)?.trim() ?? '',
      landmarkTitle: (d['landmarkTitle'] as String?)?.trim() ?? 'Landmark',
      landmarkOrder: order,
      mediaUrl: url,
      mediaType: (d['mediaType'] as String?)?.trim() == 'video'
          ? 'video'
          : 'image',
      storagePath: (d['storagePath'] as String?)?.trim() ?? '',
      source: (d['source'] as String?)?.trim(),
      createdAt: createdAt,
    );
  }

  static int? _readInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}
