import '../data/firebase/landmark_memory_data_source.dart';

/// Identifies one profile journey row (one playthrough) for scoped media/feedback loads.
class JourneyHistoryScope {
  const JourneyHistoryScope({
    required this.catalogJourneyId,
    this.explicitUserJourneyId,
    this.historyDocId,
    this.completionDocId,
    this.completedAt,
  });

  final String catalogJourneyId;
  final String? explicitUserJourneyId;
  final String? historyDocId;
  final String? completionDocId;
  final DateTime? completedAt;

  String? get userJourneyId {
    final catalog = catalogJourneyId.trim();
    bool valid(String? id) {
      final v = id?.trim();
      if (v == null || v.isEmpty) return false;
      return !LandmarkMemoryDataSource.isCatalogJourneyDocId(
        v,
        catalogJourneyId: catalog,
      );
    }

    if (valid(explicitUserJourneyId)) return explicitUserJourneyId!.trim();
    if (valid(completionDocId)) return completionDocId!.trim();
    if (valid(historyDocId)) return historyDocId!.trim();
    return null;
  }

  static String? resolveInstanceId(Map<String, dynamic> row) {
    final catalog = row['journeyId']?.toString() ?? '';
    final explicit = row['userJourneyId']?.toString().trim();
    if (explicit != null &&
        explicit.isNotEmpty &&
        !LandmarkMemoryDataSource.isCatalogJourneyDocId(
          explicit,
          catalogJourneyId: catalog,
        )) {
      return explicit;
    }
    final completion = row['completionDocId']?.toString().trim();
    if (completion != null &&
        completion.isNotEmpty &&
        !LandmarkMemoryDataSource.isCatalogJourneyDocId(
          completion,
          catalogJourneyId: catalog,
        )) {
      return completion;
    }
    final history = row['historyDocId']?.toString().trim();
    if (history != null &&
        history.isNotEmpty &&
        !LandmarkMemoryDataSource.isCatalogJourneyDocId(
          history,
          catalogJourneyId: catalog,
        )) {
      return history;
    }
    return null;
  }

  static JourneyHistoryScope fromProfileRow(Map<String, dynamic> row) {
    final journeyId = row['journeyId']?.toString().trim() ?? '';
    final rowId = row['rowId']?.toString() ?? '';
    String? historyDocId = row['historyDocId']?.toString().trim();
    String? completionDocId = row['completionDocId']?.toString().trim();

    if (rowId.startsWith('history_')) {
      historyDocId ??= rowId.substring('history_'.length);
    } else if (rowId.startsWith('completion_root_')) {
      completionDocId ??= rowId.substring('completion_root_'.length);
    } else if (rowId.startsWith('completion_')) {
      completionDocId ??= rowId.substring('completion_'.length);
    } else if (rowId.startsWith('active_')) {
      historyDocId ??= rowId.substring('active_'.length);
    }

    DateTime? completedAt;
    final sort = row['sort'];
    if (sort is DateTime) {
      completedAt = sort;
    }

    final explicitUj = row['userJourneyId']?.toString().trim();
    final catalog = journeyId;

    String? safeHistoryDocId(String? id) {
      final v = id?.trim();
      if (v == null || v.isEmpty) return null;
      if (LandmarkMemoryDataSource.isCatalogJourneyDocId(
        v,
        catalogJourneyId: catalog,
      )) {
        return null;
      }
      return v;
    }

    return JourneyHistoryScope(
      catalogJourneyId: journeyId,
      explicitUserJourneyId: explicitUj,
      historyDocId: safeHistoryDocId(historyDocId),
      completionDocId: safeHistoryDocId(completionDocId),
      completedAt: completedAt,
    );
  }

  /// Playthrough window: memories/feedback after [afterExclusive] and before [beforeExclusive].
  static ({DateTime? afterExclusive, DateTime? beforeExclusive})
  completionTimeWindow({
    required List<DateTime> completionTimesOldestFirst,
    DateTime? targetCompletedAt,
  }) {
    if (completionTimesOldestFirst.isEmpty || targetCompletedAt == null) {
      return (afterExclusive: null, beforeExclusive: null);
    }

    var idx = -1;
    for (var i = 0; i < completionTimesOldestFirst.length; i++) {
      final diff = completionTimesOldestFirst[i]
          .difference(targetCompletedAt)
          .abs();
      if (diff.inMinutes <= 3) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      for (var i = completionTimesOldestFirst.length - 1; i >= 0; i--) {
        if (!completionTimesOldestFirst[i].isAfter(targetCompletedAt)) {
          idx = i;
          break;
        }
      }
    }
    if (idx < 0) return (afterExclusive: null, beforeExclusive: null);

    final afterExclusive = idx > 0 ? completionTimesOldestFirst[idx - 1] : null;
    final beforeExclusive = idx < completionTimesOldestFirst.length - 1
        ? completionTimesOldestFirst[idx + 1]
        : null;
    return (afterExclusive: afterExclusive, beforeExclusive: beforeExclusive);
  }

  static bool timestampInPlaythroughWindow({
    required DateTime? timestamp,
    DateTime? afterExclusive,
    DateTime? beforeExclusive,
  }) {
    if (afterExclusive == null && beforeExclusive == null) return true;
    if (timestamp == null) return false;
    if (afterExclusive != null && !timestamp.isAfter(afterExclusive)) {
      return false;
    }
    if (beforeExclusive != null && !timestamp.isBefore(beforeExclusive)) {
      return false;
    }
    return true;
  }
}
