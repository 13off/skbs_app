import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/role_preview/role_preview_controller.dart';
import 'package:skbs_app/models/app_user_profile.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  tearDown(RolePreviewController.reset);

  test('просмотр роли не меняет реальную роль администратора', () {
    const admin = AppUserProfile(
      id: 'admin-id',
      email: 'admin@example.com',
      fullName: 'Администратор',
      role: 'admin',
      objectName: '',
      activeCompanyId: 'company-id',
      isActive: true,
    );

    final lawyerView = admin.previewAs(role: 'lawyer');
    final accountantView = admin.previewAs(role: 'accountant');
    final foremanView = admin.previewAs(
      role: 'foreman',
      objectName: 'Объект Чона',
    );

    expect(lawyerView.role, 'lawyer');
    expect(lawyerView.actualRole, 'admin');
    expect(accountantView.role, 'accountant');
    expect(accountantView.actualRole, 'admin');
    expect(accountantView.isRolePreview, isTrue);
    expect(foremanView.role, 'foreman');
    expect(foremanView.objectName, 'Объект Чона');
    expect(foremanView.actualRole, 'admin');
  });

  test('обычный пользователь не может подменить свою платформу', () {
    const foreman = AppUserProfile(
      id: 'foreman-id',
      email: 'foreman@example.com',
      fullName: 'Прораб',
      role: 'foreman',
      objectName: 'Объект Чона',
      activeCompanyId: 'company-id',
      isActive: true,
    );

    expect(identical(foreman.previewAs(role: 'accountant'), foreman), isTrue);
    expect(foreman.canPreviewRoles, isFalse);
  });

  test('контроллер хранит только режим интерфейса и объект прораба', () {
    RolePreviewController.showForeman(objectName: 'Объект Чона');
    expect(RolePreviewController.state.value.role, 'foreman');
    expect(RolePreviewController.state.value.objectName, 'Объект Чона');

    RolePreviewController.showLawyer();
    expect(RolePreviewController.state.value.role, 'lawyer');

    RolePreviewController.showAccountant();
    expect(RolePreviewController.state.value.role, 'accountant');
    expect(RolePreviewController.state.value.objectName, isEmpty);

    RolePreviewController.showAdmin();
    expect(RolePreviewController.state.value.role, 'admin');
  });

  test('переключатель открывает все готовые платформы без записи роли', () {
    final profile = source('lib/screens/profile_screen.dart');
    final selector = source(
      'lib/features/role_preview/role_preview_screen.dart',
    );
    final controller = source(
      'lib/features/role_preview/role_preview_controller.dart',
    );
    final main = source('lib/screens/main_screen.dart');

    expect(profile, contains("title: 'Переключить платформу'"));
    expect(profile, contains('profile.canPreviewRoles'));
    expect(selector, contains("title: 'Руководитель'"));
    expect(selector, contains("title: 'Прораб'"));
    expect(selector, contains("title: 'Юрист'"));
    expect(selector, contains("title: 'Бухгалтер'"));
    expect(selector, contains('onTap: selectAccountant'));
    expect(selector, isNot(contains("badge: 'СКОРО'")));
    expect(main, contains('AccountingMainScreen(profile: profile)'));
    expect(main, contains("'К руководителю'"));
    expect(controller, isNot(contains('Supabase')));
    expect(controller, isNot(contains(".from('company_memberships')")));
  });
}
