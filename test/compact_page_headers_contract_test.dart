import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/home_source.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('all role tabs use the same premium header as home', () {
    final header = source('lib/widgets/app_page.dart');
    final specialist = source(
      'lib/features/shared/presentation/specialist_desktop_ui.dart',
    );

    expect(header, contains('fontSize: isDesktop ? 25 : 23'));
    expect(header, contains('AppUi.pageHeaderMinHeight'));
    expect(header, contains('if (cleanSubtitle.isNotEmpty)'));
    expect(header, contains('IconButtonTheme('));
    expect(header, contains('LiquidGlassSurface('));
    expect(header, isNot(contains('PremiumBrandMark(')));
    expect(header, isNot(contains('APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ')));
    expect(specialist, contains('return AppPage('));
    expect(
      specialist,
      contains('maxContentWidth: AppUi.specialistContentWidth'),
    );
  });

  test('home tab keeps a clear title style', () {
    final home = homeSource();

    expect(home, contains("'Главная'"));
    expect(home, contains('fontSize: 20'));
  });
}
