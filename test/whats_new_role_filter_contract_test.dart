import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updates are filtered and foreman sees employee changes', () {
    final source = File(
      'lib/features/whats_new/presentation/role_aware_whats_new_gate.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("profile.role == 'admin' || profile.role == 'developer'"),
    );
    expect(source, contains('List<_UpdateSlide>.unmodifiable(_allSlides)'));
    expect(source, contains('slide.common || slide.roles.contains(role)'));
    expect(source, contains("roles: <String>{'employee', 'foreman'}"));
    expect(
      source,
      contains("roles: <String>{'employee', 'foreman', 'hr'}"),
    );
    expect(source, contains("roles: <String>{'foreman', 'accountant'}"));
    expect(
      source,
      contains(
        "roles: <String>{'procurement', 'foreman', 'accountant'}",
      ),
    );
    expect(source, contains("roles: <String>{'developer'}"));
    expect(source, contains("'procurement'"));
    expect(source, contains('common: true'));
    expect(source, contains('profile: widget.profile'));
    expect(source, contains('slides: slides'));
    expect(source, isNot(contains('Паспорт специалиста')));
  });
}
