import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all role tabs use the compact shared page header', () {
    final header = source('lib/widgets/app_page.dart');
    final specialist = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );

    expect(header, contains('PremiumBrandMark(size: 40'));
    expect(header, contains('fontSize: 24'));
    expect(header, contains('radius: 24'));
    expect(header, isNot(contains('fontSize: 30')));
    expect(specialist, contains('AppPageHeader('));
    expect(specialist, contains('EdgeInsets.fromLTRB(24, 18, 24, 120)'));
  });

  test('home tab keeps its separate compact title', () {
    final home = source('lib/screens/home_screen.dart');

    expect(home, contains("'Главная'"));
    expect(home, contains('fontSize: 20'));
    expect(home, contains('radius: 18'));
  });
}
