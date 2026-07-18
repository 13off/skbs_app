import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('administrator can preview the developer platform in PWA', () {
    final controller = File(
      'lib/features/role_preview/role_preview_controller.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/role_preview/role_preview_screen.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();

    expect(controller, contains('isDeveloperMode'));
    expect(controller, contains('showDeveloper'));
    expect(controller, contains("savedRole == 'developer'"));
    expect(screen, contains("title: 'Разработчик'"));
    expect(screen, contains('ИИ-диспетчер'));
    expect(screen, contains('onTap: selectDeveloper'));
    expect(mainScreen, contains('if (profile.isDeveloper)'));
    expect(
      mainScreen,
      isNot(contains('profile.isDeveloper && !profile.isRolePreview')),
    );
  });
}
