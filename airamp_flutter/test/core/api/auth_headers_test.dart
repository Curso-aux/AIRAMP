import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/api/auth_headers.dart';

void main() {
  test('build returns X-School-Session and X-School-User-Id headers', () {
    final headers = AuthHeaders.build(session: 'tok-abc', userId: 'user-1');
    expect(headers['X-School-Session'], 'tok-abc');
    expect(headers['X-School-User-Id'], 'user-1');
    expect(headers.containsKey('Content-Type'), isFalse);
  });
}
