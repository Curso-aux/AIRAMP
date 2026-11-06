import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Administrator archive, restore, and permanent deletion cycle', () async {
    final db = await DatabaseHelper().database;

    final testAdminId = 'A-TEST-0001';
    final testEmail = 'testadmin@aira.edu';

    // Insert test admin
    await db.insert('users', {
      'id': testAdminId,
      'email': testEmail,
      'full_name': 'Test Administrator',
      'username': 'testadmin',
      'password': 'hashed_password',
      'password_salt': 'salt123',
      'role': 'admin',
      'is_archived': 0,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 1. Should appear in active admins list
    var activeAdmins = await DatabaseHelper().getAdminsList();
    expect(activeAdmins.any((a) => a['id'] == testAdminId), isTrue);

    var archivedAdmins = await DatabaseHelper().getArchivedAdminsList();
    expect(archivedAdmins.any((a) => a['id'] == testAdminId), isFalse);

    // 2. Archive / Deactivate admin
    await DatabaseHelper().archiveAdmin(testAdminId);

    activeAdmins = await DatabaseHelper().getAdminsList();
    expect(activeAdmins.any((a) => a['id'] == testAdminId), isFalse);

    archivedAdmins = await DatabaseHelper().getArchivedAdminsList();
    expect(archivedAdmins.any((a) => a['id'] == testAdminId), isTrue);

    // 3. Restore admin
    await DatabaseHelper().restoreAdmin(testAdminId);

    activeAdmins = await DatabaseHelper().getAdminsList();
    expect(activeAdmins.any((a) => a['id'] == testAdminId), isTrue);

    archivedAdmins = await DatabaseHelper().getArchivedAdminsList();
    expect(archivedAdmins.any((a) => a['id'] == testAdminId), isFalse);

    // 4. Permanent delete
    await DatabaseHelper().deleteAdmin(testAdminId);

    activeAdmins = await DatabaseHelper().getAdminsList();
    expect(activeAdmins.any((a) => a['id'] == testAdminId), isFalse);

    archivedAdmins = await DatabaseHelper().getArchivedAdminsList();
    expect(archivedAdmins.any((a) => a['id'] == testAdminId), isFalse);

    // Verify it is recorded in permanently_deleted_accounts
    final prefs = await SharedPreferences.getInstance();
    final deletedList = prefs.getStringList('permanently_deleted_accounts') ?? [];
    expect(deletedList.contains(testAdminId), isTrue);
  });
}

