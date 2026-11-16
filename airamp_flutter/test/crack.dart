import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  final salt = 'B3VVzU92x4AfKw7KhwB7Xg==';
  final expected = 'e0c0a15ee8c6aa74f73185202fed93012be7ef7391921f33d4bc9be666962f03';
  final candidates = [
    'password', 'password123', 'student', 'student123', '123456', '12345678',
    'Student123!', 'Student@123', 'Password123!', 'Password@123', 'S-100-0001',
    'Curso', 'curso', 'curso123', 'Curso123', 'admin', 'admin123', 'P@ssword123',
    'p@ssword', 'ChangeMe123!'
  ];
  for (final c in candidates) {
    final bytes = utf8.encode(c + salt);
    final digest = sha256.convert(bytes).toString();
    if (digest == expected) {
      print('FOUND PASSWORD: $c');
      return;
    }
  }
  print('NOT FOUND in common list');
}
