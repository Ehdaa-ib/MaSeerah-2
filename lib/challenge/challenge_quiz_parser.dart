import '../model/challenge_matching_pair.dart';
import '../model/challenge_model.dart';
import '../model/challenge_stage_model.dart';
import '../model/challenge_type.dart';

/// Parses Firestore `quiz` field into [ChallengeModel] (direct or staged).
///
/// TODO: Persist partial progress / resume per landmark from Firestore.
class ChallengeQuizParser {
  ChallengeQuizParser._();

  /// Returns null when [quiz] is null, not a [Map], or yields no usable stages.
  static ChallengeModel? tryParse(
    Object? quiz, {
    String? landmarkDocumentId,
  }) {
    final map = _asStringKeyedMap(quiz);
    if (map == null) return null;

    final stageEntries = _extractStagedPayloads(map);
    if (stageEntries.isNotEmpty) {
      final stages = <ChallengeStageModel>[];
      for (var i = 0; i < stageEntries.length; i++) {
        final e = stageEntries[i];
        stages.add(_parseStageMap(
          index: i,
          stageKey: e.key,
          data: e.value,
        ));
      }
      if (stages.isEmpty) return null;
      return ChallengeModel(
        isStaged: true,
        stages: stages,
        landmarkDocumentId: landmarkDocumentId,
        rawQuiz: Map<String, dynamic>.from(map),
      );
    }

    final direct = _parseStageMap(index: 0, stageKey: null, data: map);
    return ChallengeModel(
      isStaged: false,
      stages: [direct],
      landmarkDocumentId: landmarkDocumentId,
      rawQuiz: Map<String, dynamic>.from(map),
    );
  }

  static Map<String, dynamic>? _asStringKeyedMap(Object? quiz) {
    if (quiz == null) return null;
    if (quiz is Map<String, dynamic>) return quiz;
    if (quiz is Map) {
      return quiz.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  static final RegExp _stageKey = RegExp(r'^stage(\d+)$', caseSensitive: false);

  /// Sorted list of (key, stageMap) for `stage1`, `stage2`, …
  static List<MapEntry<String, Map<String, dynamic>>> _extractStagedPayloads(
    Map<String, dynamic> map,
  ) {
    final out = <MapEntry<String, Map<String, dynamic>>>[];
    for (final e in map.entries) {
      final m = _stageKey.firstMatch(e.key);
      if (m == null) continue;
      final inner = _asStringKeyedMap(e.value);
      if (inner == null) continue;
      out.add(MapEntry(e.key, inner));
    }
    out.sort((a, b) {
      final na = int.tryParse(_stageKey.firstMatch(a.key)?.group(1) ?? '0') ?? 0;
      final nb = int.tryParse(_stageKey.firstMatch(b.key)?.group(1) ?? '0') ?? 0;
      return na.compareTo(nb);
    });
    return out;
  }

  static ChallengeStageModel _parseStageMap({
    required int index,
    required String? stageKey,
    required Map<String, dynamic> data,
  }) {
    final type = inferType(data);
    return ChallengeStageModel(
      index: index,
      stageKey: stageKey,
      type: type,
      question: readString(data['question']) ?? readString(data['prompt']),
      options: stringListFrom(data['options'] ?? data['choices']),
      hints: stringListFrom(data['hints'] ?? data['hint']),
      parts: stringListFrom(data['parts'] ?? data['segments']),
      correctOrder: stringListFrom(data['correctOrder'] ?? data['correct_order']),
      answer: data['answer'] ?? data['correctAnswer'] ?? data['solution'],
      matchingPairs: matchingPairsFrom(data),
      resultMessage: readString(data['resultMessage'] ?? data['feedback']),
      raw: Map<String, dynamic>.from(data),
    );
  }

  // --- Public helpers for reuse / tests ---

  static String? readString(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return v.toString().trim().isEmpty ? null : v.toString().trim();
  }

  static List<String> stringListFrom(Object? v) {
    if (v == null) return const [];
    if (v is List) {
      return v
          .map((e) => e == null ? '' : e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? const [] : [t];
    }
    return const [];
  }

  static List<ChallengeMatchingPair> matchingPairsFrom(Map<String, dynamic> data) {
    final out = <ChallengeMatchingPair>[];
    final raw = data['matchingPairs'] ?? data['pairs'] ?? data['matchPairs'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          final left = readString(m['left'] ?? m['a'] ?? m['from']);
          final right = readString(m['right'] ?? m['b'] ?? m['to']);
          if (left != null && right != null) {
            out.add(ChallengeMatchingPair(left: left, right: right));
          }
        }
      }
      return out;
    }
    if (raw is Map) {
      raw.forEach((k, v) {
        final left = readString(k);
        final right = readString(v);
        if (left != null && right != null) {
          out.add(ChallengeMatchingPair(left: left, right: right));
        }
      });
    }
    return out;
  }

  /// Reads explicit `type` / `challengeType` / `kind` from CMS.
  static ChallengeType? typeFromExplicitField(Map<String, dynamic> data) {
    final raw = readString(data['type'] ?? data['challengeType'] ?? data['kind']);
    if (raw == null) return null;
    switch (raw.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'fillblank':
      case 'filltheblank':
        return ChallengeType.fillBlank;
      case 'matching':
      case 'match':
        return ChallengeType.matching;
      case 'reorder':
      case 'ordering':
        return ChallengeType.reorder;
      case 'assemble':
      case 'assembly':
        return ChallengeType.assemble;
      case 'multiplechoice':
      case 'mcq':
      case 'choice':
        return ChallengeType.multipleChoice;
      case 'elimination':
      case 'eliminate':
        return ChallengeType.elimination;
      default:
        return null;
    }
  }

  /// Heuristic inference when CMS omits `type`.
  static ChallengeType inferType(Map<String, dynamic> data) {
    final explicit = typeFromExplicitField(data);
    if (explicit != null && explicit != ChallengeType.unknown) return explicit;

    if (matchingPairsFrom(data).isNotEmpty) return ChallengeType.matching;

    final parts = stringListFrom(data['parts'] ?? data['segments']);
    final order = stringListFrom(data['correctOrder'] ?? data['correct_order']);
    if (parts.isNotEmpty && order.isNotEmpty) {
      final assembleHint = readString(data['assembleStyle'] ?? data['buildMode']);
      if (assembleHint != null &&
          assembleHint.toLowerCase().contains('assemble')) {
        return ChallengeType.assemble;
      }
      return ChallengeType.reorder;
    }

    final options = stringListFrom(data['options'] ?? data['choices']);
    final hasAnswer = data.containsKey('answer') ||
        data.containsKey('correctAnswer') ||
        data.containsKey('solution');
    if (options.isNotEmpty && hasAnswer) {
      if (data['elimination'] == true ||
          readString(data['mode'])?.toLowerCase() == 'elimination') {
        return ChallengeType.elimination;
      }
      final q = readString(data['question'] ?? data['prompt']) ?? '';
      if (_looksLikeFillBlankQuestion(q) ||
          readString(data['blank']) != null) {
        return ChallengeType.fillBlank;
      }
      return ChallengeType.multipleChoice;
    }

    if (hasAnswer && options.isEmpty) {
      return ChallengeType.fillBlank;
    }

    return ChallengeType.unknown;
  }

  /// Blank token in CMS copy (e.g. `______`, `___`, mustache `{{blank}}`).
  static bool _looksLikeFillBlankQuestion(String q) {
    if (q.contains('{{')) return true;
    return RegExp(r'_{2,}').hasMatch(q);
  }
}
