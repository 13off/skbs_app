import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('leader sees all while other roles see common and own updates', () {
    final source = File(
      'lib/features/whats_new/presentation/whats_new_release_data.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("profile.role == 'admin' || profile.role == 'developer'"),
    );
    expect(source, contains('List<_UpdateSlide>.unmodifiable(_allSlides)'));
    expect(
      source,
      contains('slide.common || slide.roles.contains(profile.role)'),
    );
    expect(source, contains("roles: <String>{'admin'}"));
    expect(source, contains("roles: <String>{'admin', 'lawyer'}"));
    expect(source, contains("roles: <String>{'lawyer'}"));
    expect(source, contains("roles: <String>{'employee', 'foreman'}"));
    expect(source, contains('common: true'));

    final commonCount = RegExp('common: true').allMatches(source).length;
    expect(commonCount, 2);

    expect(source, contains('Дела руководителя'));
    expect(source, contains('Полноценная платформа юриста'));
    expect(source, contains('Единый стеклянный интерфейс'));
    expect(source, contains('Новые фото «До» и «После»'));
    expect(source, contains('Стабильнее и безопаснее'));
  });
}
