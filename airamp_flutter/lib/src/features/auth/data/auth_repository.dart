import 'package:dio/dio.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<Map<String, dynamic>> login(String identifier, String password) async {
    // TODO: Connect to real backend. Mocking for now based on RN mock structure.
    // The actual Cloudflare endpoint is /v1/auth/session
    /*
    final response = await _dio.post('/auth/session', data: {
      'identifier': identifier,
      'password': password,
    });
    return response.data;
    */
    
    await Future.delayed(const Duration(seconds: 1)); // Mock network delay
    
    final identifierLower = identifier.toLowerCase();
    
    if (identifierLower == 'aira admin' || identifierLower == 'aira@admin' || identifierLower == 'admin') {
      return {
        'user': {
          'id': 'super_admin_1',
          'email': 'aira@admin',
          'role': 'super_admin',
          'fullName': 'Aira Admin',
        }
      };
    } else if (identifierLower == 'sir john' || identifierLower == 'john.reyes@deped.gov.ph' || identifierLower.endsWith('@deped.gov.ph')) {
      return {
        'user': {
          'id': 'teacher_1',
          'email': 'john.reyes@deped.gov.ph',
          'role': 'admin', // Teachers map to admin route
          'fullName': 'Sir John',
        }
      };
    } else {
      return {
        'user': {
          'id': 'student_1',
          'email': identifier.contains('@') ? identifier : 'maria@test.com',
          'role': 'student',
          'fullName': identifier.contains('maria') ? 'Maria Lopez' : 'Mock Student',
        }
      };
    }
  }

  Future<void> logout() async {
    // await _dio.post('/auth/revoke');
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
