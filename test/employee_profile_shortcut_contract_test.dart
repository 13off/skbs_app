import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const scopePath = 'lib/navigation/platform_tab_override_scope.dart';
  const pagePath = 'lib/widgets/app_page.dart';

  test('личный профиль доступен из шапки корневых страниц сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final scope = File(scopePath).readAsStringSync();
    final page = File(pagePath).readAsStringSync();

    expect(wrapper, contains('rootHeaderTrailingBuilder:'));
    expect(wrapper, contains("tooltip: widget.profile.isRolePreview"));
    expect(wrapper, contains("'Мой профиль'"));
    expect(wrapper, contains('ProfileScreen(profile: widget.profile)'));
    expect(wrapper, contains('MaterialPageRoute<void>'));
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

  test('режим просмотра возвращает руководителя без выхода из аккаунта', () {
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, contains('RolePreviewController.showAdmin();'));
    expect(wrapper, contains("'Вернуться к руководителю'"));
    expect(wrapper, contains('Icons.admin_panel_settings_outlined'));
  });
}
