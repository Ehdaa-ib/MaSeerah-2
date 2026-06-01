/// Simple in-memory TTL cache for Firestore read deduplication (per app session).
class TtlCacheEntry<T> {
  TtlCacheEntry(this.data, this.fetchedAt);

  final T data;
  final DateTime fetchedAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) < ttl;
}

class TtlCache {
  TtlCache._();

  static final Map<String, TtlCacheEntry<dynamic>> _store = {};

  static T? read<T>(String key, Duration ttl) {
    final entry = _store[key];
    if (entry == null || !entry.isFresh(ttl)) return null;
    return entry.data as T?;
  }

  static void write<T>(String key, T data) {
    _store[key] = TtlCacheEntry<T>(data, DateTime.now());
  }

  static void invalidate(String keyPrefix) {
    _store.removeWhere((k, _) => k.startsWith(keyPrefix));
  }

  static void clear() => _store.clear();
}
