import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skbs_app/features/role_preview/role_preview_controller.dart';
import 'package:skbs_app/navigation/navigation_session.dart';

void main() {
  test('платформа и вкладка восстанавливаются после новой сессии', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await NavigationSession.configure(userId: 'user-1', companyId: 'company-1');
    await NavigationSession.writePreview(role: 'lawyer');
    await NavigationSession.writeTabIndex('lawyer', 2);

    RolePreviewController.reset(clearPersisted: false);
    await RolePreviewController.restore(canPreviewRoles: true);

    expect(RolePreviewController.state.value.role, 'lawyer');
    expect(RolePreviewController.state.value.objectName, isEmpty);
    expect(NavigationSession.readTabIndex('lawyer'), 2);

    await NavigationSession.writePreview(
      role: 'foreman',
      objectName: 'Чона',
    );
    RolePreviewController.reset(clearPersisted: false);
    await RolePreviewController.restore(canPreviewRoles: true);

    expect(RolePreviewController.state.value.role, 'foreman');
    expect(RolePreviewController.state.value.objectName, 'Чона');
  });

  test('сохранение изолировано между компаниями', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await NavigationSession.configure(userId: 'user-1', companyId: 'company-1');
    await NavigationSession.writeTabIndex('admin', 3);

    await NavigationSession.configure(userId: 'user-1', companyId: 'company-2');

    expect(NavigationSession.readTabIndex('admin'), isNull);
    expect(NavigationSession.readPreviewRole(), isNull);
  });
}
