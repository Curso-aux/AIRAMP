import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/utils/cache_manager.dart';

void main() {
  late AppCacheManager cache;

  setUp(() {
    cache = AppCacheManager();
    cache.clear();
  });

  test('set and get returns cached value before expiration', () {
    cache.set('key1', {'name': 'Neil'});
    final val = cache.get<Map<String, String>>('key1');
    expect(val, isNotNull);
    expect(val!['name'], 'Neil');
  });

  test('get returns null if key is expired', () async {
    cache.set('key_short', 'hello', ttl: const Duration(milliseconds: 10));
    await Future.delayed(const Duration(milliseconds: 25));
    final val = cache.get<String>('key_short');
    expect(val, isNull);
  });

  test('getOrFetch only invokes fetcher on cache miss or forceRefresh', () async {
    int fetchCount = 0;
    Future<String> fetcher() async {
      fetchCount++;
      return 'data_$fetchCount';
    }

    final res1 = await cache.getOrFetch('test_key', fetcher);
    expect(res1, 'data_1');
    expect(fetchCount, 1);

    // Second call should return cached data without invoking fetcher
    final res2 = await cache.getOrFetch('test_key', fetcher);
    expect(res2, 'data_1');
    expect(fetchCount, 1);

    // Force refresh should invoke fetcher
    final res3 = await cache.getOrFetch('test_key', fetcher, forceRefresh: true);
    expect(res3, 'data_2');
    expect(fetchCount, 2);
  });

  test('invalidatePrefix removes all matching prefix entries', () {
    cache.set('teacher_scores_ruby', [1, 2]);
    cache.set('teacher_scores_emerald', [3, 4]);
    cache.set('student_profile', {'id': 1});

    expect(cache.count, 3);
    cache.invalidatePrefix('teacher_scores_');
    expect(cache.count, 1);
    expect(cache.get('teacher_scores_ruby'), isNull);
    expect(cache.get('student_profile'), isNotNull);
  });
}
