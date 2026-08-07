import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leader sees all while other roles see own and employee updates', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("profile.role == 'admin' || profile.role == 'developer'"),
    );
    expect(source, contains('List<_UpdateSlide>.unmodifiable(_allSlides)'));
    expect(
      source,
      contains('slide.employeeCommon || slide.roles.contains(profile.role)'),
    );
    expect(source, contains("roles: <String>{'procurement'}"));
    expect(source, contains("roles: <String>{'hr', 'lawyer'}"));
    expect(source, contains("roles: <String>{'hr'}"));
    expect(source, contains('employeeCommon: true'));

    final commonCount = RegExp('employeeCommon: true').allMatches(source).length;
    expect(commonCount, 4);

    expect(source, contains('Новый кабинет сотрудника'));
    expect(source, contains('Геолокация и маршрут работы'));
    expect(source, contains('AppСтрой стал быстрее'));
    expect(source, contains('Исправлены ошибки'));
  });
}
