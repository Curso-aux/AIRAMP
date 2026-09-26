import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An in-memory cache entry with expiration timestamp (TTL).
class CacheEntry<T> {
  final T data;
  final DateTime createdAt;
  final Duration ttl;

  CacheEntry({
    required this.data,
    required this.createdAt,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(createdAt) > ttl;
}

/// A lightweight, robust in-memory cache manager with TTL and prefix invalidation.
///
/// Designed to eliminate redundant SQLite aggregate queries and disk I/O
/// during frequent screen/tab navigation while ensuring freshness on demand.
class AppCacheManager {
  static final AppCacheManager _instance = AppCacheManager._internal();
  factory AppCacheManager() => _instance;
  static AppCacheManager get instance => _instance;

  AppCacheManager._internal();

  final Map<String, CacheEntry<dynamic>> _storage = {};

  /// Retrieves cached value if present and not expired; otherwise returns null.
  T? get<T>(String key) {
    final entry = _storage[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _storage.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// Stores a value in the cache with the given [ttl]. Default TTL is 2 minutes.
  void set<T>(String key, T data, {Duration ttl = const Duration(minutes: 2)}) {
    _storage[key] = CacheEntry<T>(
      data: data,
      createdAt: DateTime.now(),
      ttl: ttl,
    );
  }

  /// Returns cached value if valid, or invokes [fetcher] to populate and cache it.
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher, {
    Duration ttl = const Duration(minutes: 2),
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = get<T>(key);
      if (cached != null) return cached;
    }

    final freshData = await fetcher();
    set<T>(key, freshData, ttl: ttl);
    return freshData;
  }

  /// Invalidates a specific cache key.
  void invalidate(String key) {
    _storage.remove(key);
  }

  /// Invalidates all cache entries whose keys start with [prefix].
  ///
  /// Example: `invalidatePrefix('teacher_scores')` clears all cached section/query variants.
  void invalidatePrefix(String prefix) {
    _storage.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clears the entire cache.
  void clear() {
    _storage.clear();
  }

  /// Number of active cache entries.
  int get count => _storage.length;
}

/// Riverpod provider for dependency injection and testing.
final cacheManagerProvider = Provider<AppCacheManager>((ref) {
  return AppCacheManager.instance;
});
