import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/super_admin/presentation/tabs/super_admin_profile_tab.dart';
import 'package:airamp_flutter/src/features/super_admin/presentation/tabs/super_admin_security_tab.dart';
import 'package:airamp_flutter/src/features/super_admin/data/super_admin_repository.dart';

class _MockAuthNotifier extends AuthNotifier {
  final User? _user;
  _MockAuthNotifier(this._user);

  @override
  User? build() => _user;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  final testSuperAdmin = User(
    id: 'super_admin_christian',
    email: 'evangelistachristian88@gmail.com',
    role: 'super_admin',
    fullName: 'Christian Evangelista',
    username: 'christian_super',
    schoolId: 'sch_main',
  );

  testWidgets('1. SuperAdminProfileTab renders credentials, password vault, and master keys', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(testSuperAdmin)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SuperAdminProfileTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Master Profile Header elements
    expect(find.text('Christian Evangelista'), findsAtLeastNWidgets(1));
    expect(find.text('evangelistachristian88@gmail.com'), findsAtLeastNWidgets(1));
    expect(find.text('SUPER ADMIN • ALL CAMPUSES'), findsOneWidget);

    // Verify Password & Backup Keys
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Account Access & Backup Keys'), findsOneWidget);
    expect(find.text('Emergency Backup Codes'), findsOneWidget);
    expect(find.text('AIRA-ROOT-8821-XA4F'), findsOneWidget);
    expect(find.text('Current Login & Device Info'), findsOneWidget);
  });

  testWidgets('2. SuperAdminSecurityTab renders operations bar, filter chips, and audit trail', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final mockLogs = [
      {
        'id': 'log_test_1',
        'action': 'SECURITY_RBAC_SALT_ACTIVE',
        'details': 'Cryptographic salted SHA-256 password security verified across database.',
        'actor_id': 'super_admin_christian',
        'actor_name': 'Christian Evangelista',
        'school_id': 'sch_main',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'log_test_2',
        'action': 'SYSTEM_INITIALIZATION',
        'details': 'AIRAMP Super Admin Governance loaded.',
        'actor_id': 'super_admin_christian',
        'actor_name': 'Christian Evangelista',
        'school_id': 'sch_main',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(testSuperAdmin)),
          superAdminAuditLogsProvider.overrideWith((ref) => mockLogs),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SuperAdminSecurityTab(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Security Actions Strip
    expect(find.text('All Passwords Encrypted'), findsOneWidget);
    expect(find.text('Two-Step Login On'), findsOneWidget);
    expect(find.text('Check System Health'), findsOneWidget);
    expect(find.text('Add Activity Note'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('All Events'), findsOneWidget);
    expect(find.text('Security & Logins'), findsOneWidget);
    expect(find.text('Sign-In Activity'), findsOneWidget);
    expect(find.text('Admin Accounts'), findsOneWidget);

    // Verify Event Log Items
    expect(find.text('SECURITY_RBAC_SALT_ACTIVE'), findsOneWidget);
    expect(find.text('SYSTEM_INITIALIZATION'), findsOneWidget);
    expect(find.text('View Details →'), findsNWidgets(2));
  });

  test('3. DatabaseHelper verifySecuritySaltIntegrity and audit event logging', () async {
    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;
    final uniqueId = 'user_sec_${DateTime.now().millisecondsSinceEpoch}';

    // Insert user with 64-char SHA-256 hash and 16-byte salt
    await db.insert('users', {
      'id': uniqueId,
      'email': '$uniqueId@aira.edu',
      'full_name': 'Sec Test User',
      'username': uniqueId,
      'password': 'a' * 64, // Valid 64-character SHA-256 hex string
      'password_salt': '1234567890123456',
      'role': 'teacher',
      'created_at': DateTime.now().toIso8601String(),
    });

    final auditResult = await dbHelper.verifySecuritySaltIntegrity();
    expect(auditResult['total_users'], isPositive);
    expect(auditResult['salted_users'], isPositive);
    expect(auditResult['salt_percentage'], isNotNull);

    // Log a new compliance audit event
    await dbHelper.logAuditEvent(
      action: 'SECURITY_TEST_VERIFIED',
      details: 'Automated test verified cryptographic salt compliance.',
      actorName: 'Test Suite',
    );

    final logs = await dbHelper.getAuditLogs(limit: 10);
    expect(logs.any((l) => l['action'] == 'SECURITY_TEST_VERIFIED'), isTrue);

    // Clear and archive audit logs
    await dbHelper.clearAuditLogs(actorName: 'Test Suite Runner');
    final afterArchive = await dbHelper.getAuditLogs(limit: 10);
    expect(afterArchive.any((l) => l['action'] == 'AUDIT_LOG_ARCHIVED'), isTrue);
  });
}
