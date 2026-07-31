import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrapperPath =
      'lib/features/employee/presentation/employee_platform_with_passport.dart';
  const profilePath =
      'lib/features/employee/presentation/employee_profile_screen.dart';
  const scopePath = 'lib/navigation/platform_tab_override_scope.dart';
  const pagePath = 'lib/widgets/app_page.dart';

  test('личный профиль доступен из шапки корневых страниц сотрудника', () {
    final wrapper = File(wrapperPath).readAsStringSync();
    final profile = File(profilePath).readAsStringSync();
    final scope = File(scopePath).readAsStringSync();
    final page = File(pagePath).readAsStringSync();

    expect(wrapper, contains("label: 'Задачи'"));
    expect(wrapper, contains('rootHeaderTrailingBuilder:'));
    expect(wrapper, contains("tooltip: 'Мой профиль'"));
    expect(wrapper, contains('EmployeeProfileScreen(profile: contentProfile)'));
    expect(profile, contains("label: 'Профиль'"));
    expect(profile, contains("label: 'История задач'"));
    expect(profile, contains('ProfileScreen(profile: widget.profile)'));
    expect(profile, contains('EmployeeWorkTaskHistoryScreen'));
    expect(scope, contains('final WidgetBuilder? rootHeaderTrailingBuilder;'));
    expect(scope, contains('resolveRootHeaderTrailing'));
    expect(page, contains('PlatformTabOverrideScope.resolveRootHeaderTrailing'));
    expect(page, contains('headerTrailing ?? scopedTrailing'));
  });

  test('вложенные страницы не дублируют кнопку профиля', () {
    final page = File(pagePath).readAsStringSync();

    expect(page, contains('final canPop = navigator?.canPop() ?? false;'));
    expect(page, contains('final scopedTrailing = canPop'));
    expect(
      page,
      contains('final effectiveShowBackButton = showBackButton || canPop;'),
    );
  });

  test('предпросмотр сотрудника не скрывает профиль', () {
    final wrapper = File(wrapperPath).readAsStringSync();

    expect(wrapper, contains('widget.profile.isRolePreview'));
    expect(wrapper, contains("widget.profile.copyWith(actualRole: 'employee')"));
    expect(wrapper, contains('openProfile(context, contentProfile)'));
    expect(wrapper, isNot(contains('RolePreviewController.showAdmin')));
    expect(wrapper, isNot(contains("'Вернуться к руководителю'")));
  });
}
