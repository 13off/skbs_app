import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const scopePath = 'lib/navigation/platform_tab_override_scope.dart';
  const pagePath = 'lib/widgets/app_page.dart';

  test('личный профиль временно убран из упрощённой панели сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final scope = File(scopePath).readAsStringSync();
    final page = File(pagePath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains("label: 'История задач'"));
    expect(wrapper, isNot(contains('rootHeaderTrailingBuilder:')));
    expect(wrapper, isNot(contains("'Мой профиль'")));
    expect(wrapper, isNot(contains('ProfileScreen(')));
    expect(scope, contains('final WidgetBuilder? rootHeaderTrailingBuilder;'));
    expect(scope, contains('resolveRootHeaderTrailing'));
    expect(page, contains('PlatformTabOverrideScope.resolveRootHeaderTrailing'));
    expect(page, contains('headerTrailing ?? scopedTrailing'));
  });

  test('вложенные страницы не дублируют кнопку профиля', () {
    final page = File(pagePath).readAsStringSync();

    expect(page, contains('final canPop = navigator?.canPop() ?? false;'));
    expect(page, contains('final scopedTrailing = canPop'));
    expect(page, contains('final effectiveShowBackButton = showBackButton || canPop;'));
  });

  test('в упрощённой панели нет технического значка предпросмотра', () {
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, isNot(contains('Icons.admin_panel_settings_outlined')));
    expect(wrapper, isNot(contains("'Вернуться к руководителю'")));
    expect(wrapper, isNot(contains('RolePreviewController.showAdmin')));
  });
}
