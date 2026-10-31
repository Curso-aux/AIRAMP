import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:airamp_flutter/src/core/database/firestore_service.dart';

void main() {
  group('Cloud Firestore Queue to Gmail SMTP End-to-End Tests', () {
    test('Enqueuing pending mail document is processed by SMTP Bridge daemon', () async {
      final docId = 'mail_test_e2e_${DateTime.now().millisecondsSinceEpoch}';
      final dio = Dio();
      final url = 'https://firestore.googleapis.com/v1/projects/${FirestoreService.projectId}/databases/(default)/documents/mail/$docId';

      // 1. Enqueue pending email into Firestore
      final payload = {
        'fields': {
          'to': {'stringValue': 'luyahan007@gmail.com'},
          'subject': {'stringValue': 'AIRA Automated SMTP E2E Verification'},
          'text': {'stringValue': 'Verification that Cloud Queue dispatches emails via Gmail SMTP successfully.'},
          'status': {'stringValue': 'pending'},
          'created_at': {'stringValue': DateTime.now().toIso8601String()},
          'mail_type': {'stringValue': 'e2e_verification'},
        }
      };

      final createResp = await dio.patch(url, data: payload);
      expect(createResp.statusCode, inInclusiveRange(200, 201));

      // 2. Poll document for up to 8 seconds to verify daemon processed it
      String status = 'pending';
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final getResp = await dio.get(url);
          final data = getResp.data as Map<String, dynamic>?;
          final fields = data?['fields'] as Map<String, dynamic>?;
          status = fields?['status']?['stringValue'] as String? ?? 'pending';
          if (status == 'sent_via_smtp') {
            break;
          }
        } catch (_) {}
      }

      // Cleanup test document
      try {
        await dio.delete(url);
      } catch (_) {}

      expect(status, equals('sent_via_smtp'), reason: 'Daemon must pick up pending email and mark sent_via_smtp');
    });
  });
}
