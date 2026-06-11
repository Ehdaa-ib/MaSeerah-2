import '../model/challenge_matching_pair.dart';
import '../model/challenge_model.dart';
import '../model/challenge_stage_model.dart';
import '../model/challenge_type.dart';
import 'package:flutter/foundation.dart';

/// Parses Firestore `quiz` field into [ChallengeModel] (direct or staged).
///
/// TODO: Persist partial progress / resume per landmark from Firestore.
class ChallengeQuizParser {
  ChallengeQuizParser._();

  /// Returns null when [quiz] is null, not a [Map], or yields no usable stages.
  static ChallengeModel? tryParse(Object? quiz, {String? landmarkDocumentId}) {
    // Support list-based staged schema: `quiz: [ {stage1}, {stage2} ]`
    if (quiz is List) {
      final stages = <ChallengeStageModel>[];
      for (var i = 0; i < quiz.length; i++) {
        final inner = _asStringKeyedMap(quiz[i]);
        if (inner == null) continue;
        stages.add(_parseStageMap(index: i, stageKey: 'list[$i]', data: inner));
      }
      if (stages.isEmpty) return null;
      if (kDebugMode) {
        debugPrint(
          '[ChallengeParse] landmark=$landmarkDocumentId staged=true(list) stages=${stages.length} '
          'types=${stages.map((s) => s.type.name).join(',')}',
        );
      }
      return ChallengeModel(
        isStaged: stages.length > 1,
        stages: stages,
        landmarkDocumentId: landmarkDocumentId,
        rawQuiz: const {},
      );
    }

    final map = _asStringKeyedMap(quiz);
    if (map == null) return null;

    final stageEntries = _extractStagedPayloads(map);
    if (stageEntries.isNotEmpty) {
      final stages = <ChallengeStageModel>[];
      for (var i = 0; i < stageEntries.length; i++) {
        final e = stageEntries[i];
        stages.add(_parseStageMap(index: i, stageKey: e.key, data: e.value));
      }
      if (stages.isEmpty) return null;
      if (kDebugMode) {
        debugPrint(
          '[ChallengeParse] landmark=$landmarkDocumentId staged=true stages=${stages.length} '
          'types=${stages.map((s) => s.type.name).join(',')}',
        );
      }
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

  // Supports: stage1, stage_1, stage-1, Stage 1
  static final RegExp _stageKey = RegExp(
    r'^stage[\s_-]?(\d+)$',
    caseSensitive: false,
  );

  /// Sorted list of (key, stageMap) for `stage1`, `stage2`, …
  static List<MapEntry<String, Map<String, dynamic>>> _extractStagedPayloads(
    Map<String, dynamic> map,
  ) {
    final out = <MapEntry<String, Map<String, dynamic>>>[];
    // Support array-based schemas: `stages: [ {...}, {...} ]`
    final rawStages = map['stages'] ?? map['Stages'] ?? map['challengeStages'];
    if (rawStages is List) {
      var idx = 1;
      for (final item in rawStages) {
        final m = _asStringKeyedMap(item);
        if (m == null) continue;
        // Use stage-like keys so sorting stays stable.
        out.add(MapEntry('stage$idx', m));
        idx++;
      }
      if (out.isNotEmpty) return out;
    }
    for (final e in map.entries) {
      final m = _stageKey.firstMatch(e.key);
      if (m == null) continue;
      final inner = _asStringKeyedMap(e.value);
      if (inner == null) continue;
      out.add(MapEntry(e.key, inner));
    }
    out.sort((a, b) {
      final na =
          int.tryParse(_stageKey.firstMatch(a.key)?.group(1) ?? '0') ?? 0;
      final nb =
          int.tryParse(_stageKey.firstMatch(b.key)?.group(1) ?? '0') ?? 0;
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
    if (kDebugMode) {
      final raw = readString(
        data['type'] ??
            data['challengeType'] ??
            data['kind'] ??
            data['questionType'],
      );
      final flat = raw?.toLowerCase().trim().replaceAll(RegExp(r'[\s_-]'), '');
      debugPrint(
        '[ChallengeParse] stage=$index key=${stageKey ?? 'direct'} rawType=${raw ?? 'null'} '
        'normType=${flat ?? 'null'} mapped=${type.name}',
      );
    }
    // Matching schemas often store left/right options in dedicated fields.
    final inferredParts = stringListFrom(
      data['parts'] ??
          data['segments'] ??
          data['words'] ??
          data['tokens'] ??
          data['sentenceParts'] ??
          data['sentence_parts'] ??
          data['columnA'] ??
          data['leftColumn'] ??
          data['leftItems'] ??
          data['actions'] ??
          data['questions'],
    );
    final inferredOptions = stringListFrom(
      data['options'] ??
          data['choices'] ??
          data['possibleAnswers'] ??
          data['answerOptions'] ??
          data['responses'] ??
          data['alternatives'] ??
          data['answers'] ??
          data['columnB'] ??
          data['rightColumn'] ??
          data['rightItems'] ??
          data['persons'] ??
          data['people'],
    );

    final resolvedAnswer = _normalizeAnswerForType(type, data, inferredOptions);

    return ChallengeStageModel(
      index: index,
      stageKey: stageKey,
      type: type,
      question: readString(data['question']) ?? readString(data['prompt']),
      options: inferredOptions,
      hints: stringListFrom(data['hints'] ?? data['hint']),
      parts: inferredParts,
      correctOrder: stringListFrom(
        data['correctOrder'] ??
            data['correct_order'] ??
            data['answerSequence'] ??
            data['answer_sequence'],
      ),
      answer: resolvedAnswer,
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

  static List<ChallengeMatchingPair> matchingPairsFrom(
    Map<String, dynamic> data,
  ) {
    final out = <ChallengeMatchingPair>[];
    final raw = data['matchingPairs'] ?? data['pairs'] ?? data['matchPairs'];
    if (raw is List) {
      for (final item in raw) {
        // Support list-of-lists: [ [left,right], ... ]
        if (item is List && item.length >= 2) {
          final left = readString(item[0]);
          final right = readString(item[1]);
          if (left != null && right != null) {
            out.add(ChallengeMatchingPair(left: left, right: right));
          }
          continue;
        }
        if (item is Map) {
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          final left = readString(m['left'] ?? m['a'] ?? m['from']);
          final right = readString(m['right'] ?? m['b'] ?? m['to']);
          if (left != null && right != null) {
            out.add(ChallengeMatchingPair(left: left, right: right));
          }
          // Support prompt/answer keys.
          final l2 = readString(m['prompt']);
          final r2 = readString(m['answer']);
          if (l2 != null && r2 != null) {
            out.add(ChallengeMatchingPair(left: l2, right: r2));
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

    // Region 2 schema: `correctmatches: [ {question: "...", answer: "..."}, ... ]`
    final cm =
        data['correctmatches'] ??
        data['correctMatches'] ??
        data['correct_matches'];
    if (out.isEmpty && cm is List) {
      for (final item in cm) {
        if (item is Map) {
          final m = item.map((k, v) => MapEntry(k.toString(), v));
          final q = readString(
            m['question'] ?? m['prompt'] ?? m['action'] ?? m['left'],
          );
          final a = readString(m['answer'] ?? m['person'] ?? m['right']);
          if (q != null && a != null) {
            out.add(ChallengeMatchingPair(left: q, right: a));
          }
        }
      }
    }
    // Alternate schemas:
    // - leftItems/rightItems + correctMatches/matches
    // - actions/persons + correctMatches/matches
    final leftCol = stringListFrom(
      data['leftColumn'] ??
          data['leftItems'] ??
          data['actions'] ??
          data['left'] ??
          data['columnA'],
    );
    final rightCol = stringListFrom(
      data['rightColumn'] ??
          data['rightItems'] ??
          data['persons'] ??
          data['right'] ??
          data['columnB'],
    );
    final matches = data['correctMatches'] ?? data['matches'];
    if (out.isEmpty &&
        leftCol.isNotEmpty &&
        rightCol.isNotEmpty &&
        matches is Map) {
      matches.forEach((k, v) {
        final l = readString(k);
        final r = readString(v);
        if (l != null && r != null) {
          out.add(ChallengeMatchingPair(left: l, right: r));
        }
      });
    }
    return out;
  }

  /// MCQ-style option lists (same keys as [inferType] heuristics).
  static List<String> optionListFromQuizMap(Map<String, dynamic> data) {
    return stringListFrom(
      data['options'] ??
          data['choices'] ??
          data['possibleAnswers'] ??
          data['answerOptions'] ??
          data['responses'] ??
          data['alternatives'] ??
          data['answers'],
    );
  }

  static bool _hasMeaningfulAnswerField(Map<String, dynamic> data) {
    const keys = [
      'answer',
      'correctAnswer',
      'solution',
      'correct_answer',
      'selectedAnswer',
      'correctIndex',
      'answerIndex',
      'correct_choice',
    ];
    for (final k in keys) {
      if (!data.containsKey(k)) continue;
      final v = data[k];
      if (v == null) continue;
      if (v is String && v.trim().isEmpty) continue;
      return true;
    }
    return false;
  }

  static Object? _rawAnswerFromData(Map<String, dynamic> data) {
    return data['answer'] ??
        data['correctAnswer'] ??
        data['solution'] ??
        data['correct_answer'] ??
        data['selectedAnswer'] ??
        data['correctIndex'] ??
        data['answerIndex'] ??
        data['correct_choice'];
  }

  /// Some CMS entries store the correct MCQ as a 0-based index; UI compares option strings.
  static Object? _normalizeAnswerForType(
    ChallengeType type,
    Map<String, dynamic> data,
    List<String> options,
  ) {
    final raw = _rawAnswerFromData(data);
    if (type == ChallengeType.multipleChoice ||
        type == ChallengeType.arrangeSentenceWithMultipleChoice) {
      final coerced = _coerceAnswerIndexToOptionText(raw, options);
      if (coerced != null) return coerced;
    }
    return raw;
  }

  static String? _coerceAnswerIndexToOptionText(
    Object? raw,
    List<String> options,
  ) {
    if (options.isEmpty || raw == null) return null;
    int? idx;
    if (raw is int) {
      idx = raw;
    } else if (raw is double) {
      if (raw.isNaN || raw.isInfinite) return null;
      final r = raw.round();
      if ((raw - r).abs() > 1e-9) return null;
      idx = r;
    } else if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      for (final o in options) {
        if (t.toLowerCase() == o.trim().toLowerCase()) return null;
      }
      idx = int.tryParse(t);
      if (idx == null) return null;
    } else {
      return null;
    }
    if (idx < 0 || idx >= options.length) return null;
    return options[idx];
  }

  /// Reads explicit `type` / `challengeType` / `kind` from CMS.
  static ChallengeType? typeFromExplicitField(Map<String, dynamic> data) {
    final raw = readString(
      data['type'] ??
          data['challengeType'] ??
          data['kind'] ??
          data['questionType'],
    );
    if (raw == null) return null;
    final key = raw.toLowerCase().trim();
    final flat = key.replaceAll(RegExp(r'[\s_-]'), '');
    switch (flat) {
      case 'fillblankwithchoices':
        return ChallengeType.fillBlankWithChoices;
      case 'matchcolumns':
      case 'matchcolumn':
        return ChallengeType.matchColumns;
      case 'orderevents':
      case 'ordering':
        return ChallengeType.orderEvents;
      case 'ordereventsstyled':
        return ChallengeType.orderEventsStyled;
      case 'arrangesentencealternative':
      case 'arrangesentence':
      case 'sentencebuilder':
        return ChallengeType.arrangeSentenceAlternative;
      case 'multiplechoice':
      case 'mcq':
      case 'choice':
      case 'singlechoice':
      case 'selectone':
      case 'radio':
      case 'quizmultiplechoice':
        return ChallengeType.multipleChoice;
      case 'fillblankwithmultiplechoice':
        return ChallengeType.fillBlankWithMultipleChoice;
      case 'arrangesentencewithmultiplechoice':
        return ChallengeType.arrangeSentenceWithMultipleChoice;
      case 'fillblank':
      case 'filltheblank':
        return ChallengeType.fillBlank;
      case 'matching':
      case 'match':
        return ChallengeType.matching;
      case 'reorder':
        return ChallengeType.reorder;
      case 'assemble':
      case 'assembly':
        return ChallengeType.assemble;
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

    if (matchingPairsFrom(data).isNotEmpty) return ChallengeType.matchColumns;
    // Heuristic: left/right columns indicate matching.
    if (stringListFrom(
          data['leftColumn'] ?? data['columnA'] ?? data['actions'],
        ).isNotEmpty &&
        stringListFrom(
          data['rightColumn'] ?? data['columnB'] ?? data['persons'],
        ).isNotEmpty) {
      return ChallengeType.matchColumns;
    }

    // Duolingo-style sentence builder keys → arrange sentence.
    if (stringListFrom(
      data['words'] ??
          data['tokens'] ??
          data['sentenceParts'] ??
          data['sentence_parts'],
    ).isNotEmpty) {
      return ChallengeType.arrangeSentenceAlternative;
    }

    final parts = stringListFrom(data['parts'] ?? data['segments']);
    final order = stringListFrom(data['correctOrder'] ?? data['correct_order']);
    if (parts.isNotEmpty && order.isNotEmpty) {
      // Some CMS entries represent sentence arrangement using `parts/correctOrder`.
      // If the prompt mentions arranging a sentence, render the Duolingo-style builder.
      final q = (readString(data['question'] ?? data['prompt']) ?? '')
          .toLowerCase();
      if (q.contains('arrange') && q.contains('sentence')) {
        return ChallengeType.arrangeSentenceAlternative;
      }
      final assembleHint = readString(
        data['assembleStyle'] ?? data['buildMode'],
      );
      if (assembleHint != null &&
          assembleHint.toLowerCase().contains('assemble')) {
        return ChallengeType.assemble;
      }
      return ChallengeType.orderEvents;
    }

    final options = optionListFromQuizMap(data);
    final hasAnswer = _hasMeaningfulAnswerField(data);
    if (options.isNotEmpty && hasAnswer) {
      if (data['elimination'] == true ||
          readString(data['mode'])?.toLowerCase() == 'elimination') {
        return ChallengeType.elimination;
      }
      final q = readString(data['question'] ?? data['prompt']) ?? '';
      if (_looksLikeFillBlankQuestion(q) || readString(data['blank']) != null) {
        // If options exist, default to the chip-based fill blank.
        return options.isNotEmpty
            ? ChallengeType.fillBlankWithChoices
            : ChallengeType.fillBlank;
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
