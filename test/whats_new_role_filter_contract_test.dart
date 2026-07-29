import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('what is new filters updates by role and gives admin every slide', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains("if (profile.role == 'admin')"));
    expect(
      source,
      contains('List<_WhatsNewSlide>.unmodifiable(_allSlides)'),
    );
    expect(source, contains('slide.common || slide.roles.contains(role)'));
    expect(source, contains("roles: <String>{'developer'}"));
    expect(source, contains("roles: <String>{'foreman', 'employee'}"));
    expect(source, contains("roles: <String>{'hr'}"));
    expect(source, contains("roles: <String>{'accountant'}"));
    expect(source, contains("roles: <String>{'hr', 'lawyer'}"));
    expect(source, contains("'developer'"));
    expect(source, contains("'foreman'"));
    expect(source, contains("'employee'"));
    expect(source, contains("'lawyer'"));
    expect(source, contains("'accountant'"));
    expect(source, contains("'hr'"));
    expect(source, contains('common: true'));
    expect(source, contains('profile: widget.profile'));
    expect(source, contains('slides: slides'));
    expect(source, isNot(contains('profile.isAdmin')));
  });
}
