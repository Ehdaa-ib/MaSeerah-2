import '../model/challenge_matching_pair.dart';

/// Shared validation for challenge UIs.
///
/// TODO: Align with server-side validation / Firestore rules when scoring is added.
class ChallengeValidation {
  ChallengeValidation._();

  static String _norm(String s) => s.trim().toLowerCase();

  /// Single-value answers (MC, fill blank, elimination final pick, etc.).
  static bool validateStringAnswer({
    required String candidate,
    required Object? expected,
    bool caseInsensitive = true,
  }) {
    final c = candidate.trim();
    if (c.isEmpty) return false;
    if (expected == null) return false;

    if (expected is String) {
      final e = expected.trim();
      if (e.isEmpty) return false;
      return caseInsensitive ? _norm(c) == _norm(e) : c == e;
    }

    if (expected is List) {
      for (final e in expected) {
        if (e == null) continue;
        final es = e.toString().trim();
        if (es.isEmpty) continue;
        final ok = caseInsensitive ? _norm(c) == _norm(es) : c == es;
        if (ok) return true;
      }
      return false;
    }

    if (expected is Map) {
      for (final v in expected.values) {
        if (validateStringAnswer(
          candidate: c,
          expected: v,
          caseInsensitive: caseInsensitive,
        )) {
          return true;
        }
      }
      return false;
    }

    return caseInsensitive
        ? _norm(c) == _norm(expected.toString())
        : c == expected.toString().trim();
  }

  /// Order-sensitive: user order must match [expectedOrder] element-wise.
  static bool validateListOrderAnswer({
    required List<String> userOrder,
    required List<String> expectedOrder,
    bool caseInsensitive = true,
  }) {
    if (userOrder.length != expectedOrder.length) return false;
    for (var i = 0; i < userOrder.length; i++) {
      final a = userOrder[i].trim();
      final b = expectedOrder[i].trim();
      if (a.isEmpty || b.isEmpty) return false;
      final ok = caseInsensitive ? _norm(a) == _norm(b) : a == b;
      if (!ok) return false;
    }
    return true;
  }

  /// Remaining items after elimination compared as sorted multisets of strings.
  static bool validateEliminationAnswer({
    required List<String> remaining,
    required Object? expected,
  }) {
    List<String> normList(Object? o) {
      if (o is List) {
        return o
            .map((e) => _norm(e.toString()))
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort();
      }
      if (o is String) {
        final s = _norm(o);
        return s.isEmpty ? <String>[] : [s];
      }
      return const [];
    }

    final rem = normList(remaining);
    final exp = normList(expected);
    if (rem.length != exp.length) return false;
    for (var i = 0; i < rem.length; i++) {
      if (rem[i] != exp[i]) return false;
    }
    return true;
  }

  /// [userMatches]: left label (as shown) -> chosen right label.
  static bool validateMatchingAnswer({
    required Map<String, String> userMatches,
    required List<ChallengeMatchingPair> expectedPairs,
  }) {
    if (expectedPairs.isEmpty) return false;
    if (userMatches.length != expectedPairs.length) return false;
    for (final p in expectedPairs) {
      String? userKey;
      for (final k in userMatches.keys) {
        if (_norm(k) == _norm(p.left)) {
          userKey = k;
          break;
        }
      }
      if (userKey == null) return false;
      final chosen = userMatches[userKey];
      if (chosen == null || _norm(chosen) != _norm(p.right)) return false;
    }
    return true;
  }
}
