import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/utils/institutional_id_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';

void main() {
  group('Campus Identifier Auto-Generation Tests', () {
    test('Derives clean 3-letter acronym from standard campus names', () {
      expect(
        InstitutionalIdHelper.generateCampusCode(
          campusName: 'Quezon City Science High School',
        ),
        'QCS-01',
      );

      expect(
        InstitutionalIdHelper.generateCampusCode(
          campusName: 'Manila Science High School',
        ),
        'MAS-01',
      );

      expect(
        InstitutionalIdHelper.generateCampusCode(
          campusName: 'AIRAMP Demonstration High School',
        ),
        'AID-01',
      );
    });

    test('Auto-increments sequence when code prefix already exists', () {
      final existing = ['QCS-01', 'QCS-02'];
      final nextCode = InstitutionalIdHelper.generateCampusCode(
        campusName: 'Quezon City South High School',
        existingCodes: existing,
      );
      expect(nextCode, 'QCS-03');
    });

    test('Handles short or single-word campus names cleanly', () {
      expect(
        InstitutionalIdHelper.generateCampusCode(campusName: 'Cavite'),
        'CAV-01',
      );

      expect(
        InstitutionalIdHelper.generateCampusCode(campusName: 'St. Jude Academy'),
        'STJ-01',
      );

      expect(
        InstitutionalIdHelper.generateCampusCode(campusName: ''),
        'CMP-01',
      );
    });
  });

  group('Campus Administrator Multi-Tenancy Scoping Tests', () {
    test('Unassigned Campus Admin retains null schoolId and never defaults to sch_main', () {
      final adminUser = User(
        id: 'ADM-2026-0001',
        email: 'newadmin@institution.edu',
        role: 'admin',
        fullName: 'New Campus Admin',
        schoolId: null,
      );

      expect(adminUser.schoolId, isNull);
      expect(adminUser.isSchoolAdmin, isTrue);
      expect(adminUser.isSuperAdmin, isFalse);
    });

    test('User.fromJson preserves null schoolId for unassigned admin', () {
      final json = {
        'id': 'ADM-2026-0002',
        'email': 'unassigned@institution.edu',
        'role': 'admin',
        'fullName': 'Pending Admin',
        'school_id': null,
      };

      final user = User.fromJson(json);
      expect(user.schoolId, isNull);
    });

    test('User.fromJson preserves sch_main fallback only for legacy students', () {
      final json = {
        'id': 'STD-2026-0001',
        'email': 'student@institution.edu',
        'role': 'student',
        'fullName': 'Legacy Student',
        'school_id': null,
      };

      final user = User.fromJson(json);
      expect(user.schoolId, 'sch_main');
    });

    test('Bidirectional admin-to-campus resolution matches when either school.admin_id or user.school_id is set', () {
      final List<Map<String, dynamic>> schools = [
        {'id': 'sch_main', 'code': 'ADM-01', 'name': 'Main Campus', 'admin_id': 'ADM-01'},
        {'id': 'sch_cavite', 'code': 'CAV-01', 'name': 'Cavite Campus', 'admin_id': null},
      ];
      final List<Map<String, dynamic>> admins = [
        {'id': 'ADM-01', 'full_name': 'Admin One', 'school_id': 'sch_main'},
        {'id': 'ADM-02', 'full_name': 'Admin Two', 'school_id': 'sch_cavite'},
        {'id': 'ADM-03', 'full_name': 'Admin Three', 'school_id': null},
      ];

      // Campus with admin_id set resolves directly
      final mainAssigned = admins.firstWhere(
        (a) => a['id'] == schools[0]['admin_id'] || (a['school_id'] == schools[0]['id'] && (schools[0]['admin_id'] == null)),
        orElse: () => <String, dynamic>{},
      );
      expect(mainAssigned['id'], 'ADM-01');

      // Campus with null admin_id resolves via admin's school_id
      final caviteAssigned = admins.firstWhere(
        (a) => a['id'] == schools[1]['admin_id'] || (a['school_id'] == schools[1]['id'] && (schools[1]['admin_id'] == null)),
        orElse: () => <String, dynamic>{},
      );
      expect(caviteAssigned['id'], 'ADM-02');

      // Unassigned admin is not matched to either
      final isUnassigned = !schools.any((s) => s['admin_id'] == admins[2]['id'] || (s['id'] == admins[2]['school_id']));
      expect(isUnassigned, isTrue);
    });
  });
}
