import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all role tabs use the same plain header as home', () {
    final header = source('lib/widgets/app_page.dart');
    final specialist = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );

    expect(header, contains('fontSize: 20'));
    expect(header, contains('AppUi.pageHeaderMinHeight'));
    expect(header, contains('cleanSubtitle.isEmpty'));
    expect(header, contains('IconButtonTheme('));
    expect(header, isNot(contains('PremiumBrandMark(')));
    expect(header, isNot(contains('APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ')));
    expect(header, isNot(contains('PremiumWorkCard(')));
    expect(specialist, contains('return AppPage('));
    expect(specialist, contains('maxContentWidth: AppUi.specialistContentWidth'));
  });

  test('home tab keeps the same plain title style', () {
    final home = homeSource();

    expect(home, contains("'Главная'"));
    expect(home, contains('fontSize: 20'));
  });
}
