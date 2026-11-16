import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:airamp_flutter/src/core/services/cloudflare_r2_service.dart';

void main() {
  group('CloudflareR2Service getAccessibleUrl Tests', () {
    test('Converts publicDevUrl to signed presigned URL', () {
      final r2 = CloudflareR2Service.instance;
      const testPath = 'submissions/assign_564/S-100-0001_1794854987159_Group_No_5_CaseStudy_POBLACION.pdf';
      const devUrl = 'https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev/$testPath';

      final accessibleUrl = r2.getAccessibleUrl(devUrl);

      expect(accessibleUrl.startsWith('https://04f40ee82af58f1db27171ca2c8cd61e.r2.cloudflarestorage.com/aira-storage/$testPath'), isTrue);
      expect(accessibleUrl.contains('X-Amz-Algorithm=AWS4-HMAC-SHA256'), isTrue);
      expect(accessibleUrl.contains('X-Amz-Signature='), isTrue);
      expect(accessibleUrl.contains('X-Amz-Expires='), isTrue);
    });

    test('Converts direct R2 host URL to signed presigned URL', () {
      final r2 = CloudflareR2Service.instance;
      const testPath = 'submissions/assign_564/test.pdf';
      const directUrl = 'https://04f40ee82af58f1db27171ca2c8cd61e.r2.cloudflarestorage.com/aira-storage/$testPath';

      final accessibleUrl = r2.getAccessibleUrl(directUrl);

      expect(accessibleUrl.startsWith('https://04f40ee82af58f1db27171ca2c8cd61e.r2.cloudflarestorage.com/aira-storage/$testPath'), isTrue);
      expect(accessibleUrl.contains('X-Amz-Signature='), isTrue);
    });

    test('Preserves external non-R2 URLs unmodified', () {
      final r2 = CloudflareR2Service.instance;
      const googleDriveUrl = 'https://drive.google.com/file/d/12345/view';
      const firebaseStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/bucket/o/test.pdf';

      expect(r2.getAccessibleUrl(googleDriveUrl), equals(googleDriveUrl));
      expect(r2.getAccessibleUrl(firebaseStorageUrl), equals(firebaseStorageUrl));
    });

    test('Handles relative paths in R2', () {
      final r2 = CloudflareR2Service.instance;
      const relPath = 'submissions/assign_100/sample.pdf';

      final accessibleUrl = r2.getAccessibleUrl(relPath);

      expect(accessibleUrl.startsWith('https://04f40ee82af58f1db27171ca2c8cd61e.r2.cloudflarestorage.com/aira-storage/$relPath'), isTrue);
      expect(accessibleUrl.contains('X-Amz-Signature='), isTrue);
    });

    test('Live HTTP GET to presigned URL returns 200 OK', () async {
      final r2 = CloudflareR2Service.instance;
      const devUrl = 'https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev/submissions/assign_564/S-100-0001_1794854987159_Group_No_5_CaseStudy_POBLACION.pdf';
      final accessibleUrl = r2.getAccessibleUrl(devUrl);
      final resp = await Dio().get<List<int>>(
        accessibleUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      expect(resp.statusCode, equals(200));
      expect(resp.data?.length, greaterThan(1000));
    });
  });
}
