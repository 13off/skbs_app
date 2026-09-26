import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('current updates are shown only to roles that use each feature', () {
    final source = File(
      'lib/features/whats_new/presentation/whats_new_release_data.dart',
    ).readAsStringSync();

    expect(source, contains("roles: <String>{'foreman', 'employee'}"));
    expect(source, contains("roles: <String>{'accountant'}"));
    expect(source, contains("roles: <String>{'executive'}"));
    expect(source, contains('slide.roles.contains(profile.role)'));

    expect(
      source,
      isNot(contains("profile.role == 'admin' || profile.role == 'developer'")),
    );
    expect(source, isNot(contains('common: true')));

    expect(source, contains('Фото и видео в задачах'));
    expect(source, contains('Копейки — через точку или запятую'));
    expect(source, contains('Аванс 30% в «Оплате»'));
  });
}
