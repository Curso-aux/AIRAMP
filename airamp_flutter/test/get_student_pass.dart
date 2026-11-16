import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = r'C:\Users\Neil\.gemini\antigravity\brain\2eac6e52-4ad4-4b5e-a275-a0042708e1f6\airamp_local.db';
  final db = await openDatabase(dbPath);
  final users = await db.query('users', where: 'id = ?', whereArgs: ['S-100-0001']);
  print('User S-100-0001: $users');
  await db.close();
}
