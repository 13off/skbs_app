import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const scopePath = 'lib/navigation/platform_tab_override_scope.dart';
  const pagePath = 'lib/widgets/app_page.dart';
  const previewPath = 'lib/features/role_preview/role_preview_shell.dart';

  test('личный профиль доступен из шапки реального сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final scope = File(scopePath).readAsStringSync();
    final page = File(pagePath).readAsStringSync();

    expect(wrapper, contains('rootHeaderTrailingBuilder:'));
    expect(wrapper, contains('profile.isRolePreview'));
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

  test('в предпросмотре технический значок не дублирует общий возврат', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final preview = File(previewPath).readAsStringSync();

    expect(wrapper, contains('profile.isRolePreview'));
    expect(wrapper, contains('? null'));
    expect(wrapper, isNot(contains('Icons.admin_panel_settings_outlined')));
    expect(wrapper, isNot(contains("'Вернуться к руководителю'")));
    expect(preview, contains('RolePreviewController.showAdmin'));
  });
}
