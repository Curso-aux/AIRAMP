import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/core/utils/institutional_id_helper.dart';

void main() {
  group('InstitutionalIdHelper Tests', () {
    test('normalizes and auto-hyphenates IDs', () {
      expect(InstitutionalIdHelper.normalize('s1000001'), equals('S-100-0001'));
      expect(InstitutionalIdHelper.normalize('t1000002'), equals('T-100-0002'));
      expect(InstitutionalIdHelper.normalize('a1000001'), equals('A-100-0001'));
      expect(InstitutionalIdHelper.normalize('sa0000001'), equals('SA-000-0001'));
      expect(InstitutionalIdHelper.normalize('  S-100-0005  '), equals('S-100-0005'));
    });

    test('detects roles accurately from ID prefixes', () {
      expect(InstitutionalIdHelper.detectRole('SA-000-0001'), equals('super_admin'));
      expect(InstitutionalIdHelper.detectRole('A-100-0001'), equals('admin'));
      expect(InstitutionalIdHelper.detectRole('T-100-0001'), equals('teacher'));
      expect(InstitutionalIdHelper.detectRole('S-100-0001'), equals('student'));

      // Legacy support
      expect(InstitutionalIdHelper.detectRole('001-0001'), equals('student'));
      expect(InstitutionalIdHelper.detectRole('002-0001'), equals('teacher'));
      expect(InstitutionalIdHelper.detectRole('ADM-01'), equals('admin'));
    });

    test('validates institutional ID format', () {
      expect(InstitutionalIdHelper.isValid('S-100-0001'), isTrue);
      expect(InstitutionalIdHelper.isValid('T-100-0042'), isTrue);
      expect(InstitutionalIdHelper.isValid('A-100-0001'), isTrue);
      expect(InstitutionalIdHelper.isValid('SA-000-0001'), isTrue);

      // Legacy
      expect(InstitutionalIdHelper.isValid('001-0001'), isTrue);
      expect(InstitutionalIdHelper.isValid('002-0001'), isTrue);

      // Invalid
      expect(InstitutionalIdHelper.isValid('random_string'), isFalse);
      expect(InstitutionalIdHelper.isValid('12345'), isFalse);
    });
  });
}

