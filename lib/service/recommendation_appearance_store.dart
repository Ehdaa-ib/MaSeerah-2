import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists which recommendation [order] values have already been auto-shown on the map for a journey.
class RecommendationAppearanceStore {
  RecommendationAppearanceStore();

  /// Same composite key as [JourneyMapScreen] uses for prefs (landmarks id + catalog id).
  static String journeyKey({
    required String landmarksJourneyId,
    String? catalogJourneyId,
  }) {
    final c = catalogJourneyId?.trim() ?? '';
    return '${landmarksJourneyId.trim()}|$c';
  }

  /// `journey1` → `journey_1` (matches map inference when [catalogJourneyId] was omitted in older builds).
  static String? inferCatalogFromLandmarksId(String landmarksJourneyId) {
    final m = RegExp(r'^journey(\d+)$').firstMatch(landmarksJourneyId.trim());
    if (m == null) return null;
    return 'journey_${m.group(1)}';
  }

  /// All prefs key suffixes that may have been used for this journey (legacy `landmarks|` vs `landmarks|catalog`).
  static Set<String> journeyKeyVariants({
    required String landmarksJourneyId,
    String? catalogJourneyId,
  }) {
    final lm = landmarksJourneyId.trim();
    if (lm.isEmpty) return {};
    final out = <String>{
      journeyKey(landmarksJourneyId: lm, catalogJourneyId: catalogJourneyId),
      journeyKey(landmarksJourneyId: lm, catalogJourneyId: null),
    };
    final inferred = inferCatalogFromLandmarksId(lm);
    final cat = catalogJourneyId?.trim();
    if (inferred != null && inferred.isNotEmpty && inferred != cat) {
      out.add(journeyKey(landmarksJourneyId: lm, catalogJourneyId: inferred));
    }
    return out;
  }

  static String _prefsKey(String journeyKey, {String? userId}) {
    final id = (userId != null && userId.isNotEmpty) ? userId : 'guest';
    return 'map_rec_auto_shown_v1_${id}_$journeyKey';
  }

  /// Clears auto-shown recommendation orders for this journey (local only; Firestore untouched).
  /// Removes every [journeyKeyVariants] entry so stale keys do not repopulate the list.
  Future<void> clearAppearedForJourney({
    required String landmarksJourneyId,
    String? catalogJourneyId,
  }) async {
    if (landmarksJourneyId.trim().isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final variants = journeyKeyVariants(
      landmarksJourneyId: landmarksJourneyId,
      catalogJourneyId: catalogJourneyId,
    );
    for (final composite in variants) {
      await prefs.remove(_prefsKey(composite, userId: uid));
    }
    if (kDebugMode) {
      debugPrint('[RecommendationStore] cleared appeared variants=$variants');
    }
  }

  Future<Set<int>> loadAppearedOrders(String journeyKey) async {
    if (journeyKey.isEmpty) return {};
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey(journeyKey, userId: uid));
    if (raw == null || raw.isEmpty) return {};
    final out = <int>{};
    for (final s in raw) {
      final o = int.tryParse(s.trim());
      if (o != null) out.add(o);
    }
    return out;
  }

  /// Overwrites the stored set (e.g. after pruning to current map tier).
  Future<void> writeAppearedOrders(String journeyKey, Set<int> orders) async {
    if (journeyKey.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(journeyKey, userId: uid);
    final list = orders.map((e) => '$e').toList()..sort();
    await prefs.setStringList(key, list);
  }

  Future<void> markAppeared(String journeyKey, int order) async {
    if (journeyKey.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final prefs = await SharedPreferences.getInstance();
    final key = _prefsKey(journeyKey, userId: uid);
    final cur = prefs.getStringList(key) ?? [];
    final set = cur.map(int.tryParse).whereType<int>().toSet()..add(order);
    await prefs.setStringList(key, set.map((e) => '$e').toList()..sort());
    if (kDebugMode) {
      debugPrint('[RecommendationStore] journey=$journeyKey appeared orders=$set');
    }
  }
}
