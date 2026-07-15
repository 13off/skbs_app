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
    final foremanView = admin.previewAs(
      role: 'foreman',
      objectName: 'Объект Чона',
    );

    expect(lawyerView.role, 'lawyer');
    expect(lawyerView.actualRole, 'admin');
    expect(lawyerView.isRolePreview, isTrue);
    expect(lawyerView.canPreviewRoles, isTrue);
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

    expect(identical(foreman.previewAs(role: 'lawyer'), foreman), isTrue);
    expect(foreman.canPreviewRoles, isFalse);
  });

  test('контроллер хранит только режим интерфейса и объект прораба', () {
    RolePreviewController.showForeman(objectName: 'Объект Чона');
    expect(RolePreviewController.state.value.role, 'foreman');
    expect(RolePreviewController.state.value.objectName, 'Объект Чона');

    RolePreviewController.showLawyer();
    expect(RolePreviewController.state.value.role, 'lawyer');
    expect(RolePreviewController.state.value.objectName, isEmpty);

    RolePreviewController.showAdmin();
    expect(RolePreviewController.state.value.role, 'admin');
  });

  test('переключатель встроен в профиль и не пишет роль в Supabase', () {
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
    expect(selector, contains("badge: 'СКОРО'"));
    expect(selector, contains('ObjectRepository.fetchObjectNames()'));
    expect(main, contains("'К руководителю'"));
    expect(main, contains('KeyedSubtree'));
    expect(controller, isNot(contains('Supabase')));
    expect(controller, isNot(contains(".from('company_memberships')")));
  });
}
