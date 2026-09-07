import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sessions table exists at v9', () async {
    final helper = DatabaseHelper();
    final db = await helper.database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'",
    );
    expect(result, isNotEmpty);
    expect(result.first['name'], 'sessions');
  });
}
