import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/auth/data/employee_auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('EmployeeAuthRepository.normalizeRussianPhone', () {
    test('normalizes a local ten digit number', () {
      expect(
        EmployeeAuthRepository.normalizeRussianPhone('999 123-45-67'),
        '+79991234567',
      );
    });

    test('replaces the Russian trunk prefix', () {
      expect(
        EmployeeAuthRepository.normalizeRussianPhone('8 (999) 123-45-67'),
        '+79991234567',
      );
    });

    test('keeps an international Russian number', () {
      expect(
        EmployeeAuthRepository.normalizeRussianPhone('+7 999 123-45-67'),
        '+79991234567',
      );
    });

    test('rejects an incomplete number', () {
      expect(
        () => EmployeeAuthRepository.normalizeRussianPhone('12345'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
