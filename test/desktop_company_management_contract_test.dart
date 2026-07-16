import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company management keeps mobile screen and adds desktop center', () {
    final adaptive = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );
    final mobile = source(
      'lib/features/company/presentation/mobile_company_management_screen.dart',
    );
    final desktop = source(
      'lib/features/company/presentation/desktop_company_management_screen.dart',
    );

    expect(adaptive, contains('kIsWeb'));
    expect(adaptive, contains('constraints.maxWidth >= desktopBreakpoint'));
    expect(adaptive, contains('desktopBreakpoint = 1050'));
    expect(adaptive, contains('DesktopCompanyManagementScreen'));
    expect(adaptive, contains('mobile.CompanyManagementScreen'));
    expect(mobile, contains("title: const Text('Компания и пользователи')"));
    expect(mobile, contains('CompanyMemberEditorScreen'));
    expect(desktop, contains("title: 'Компания и пользователи'"));
    expect(desktop, contains('SpecialistDesktopTable'));
    expect(desktop, contains("title: 'Команда'"));
    expect(desktop, contains("title: 'Приглашения'"));
  });

  test('desktop team center exposes roles objects access and search', () {
    final desktop = source(
      'lib/features/company/presentation/desktop_company_management_screen.dart',
    );
    final dialogs = source(
      'lib/features/company/presentation/desktop_company_user_dialogs.dart',
    );

    expect(desktop, contains("hintText: 'ФИО, email, роль или объект...'"));
    expect(desktop, contains("labelText: 'Роль'"));
    expect(desktop, contains("labelText: 'Объект'"));
    expect(desktop, contains("labelText: 'Доступ'"));
    expect(desktop, contains("SpecialistTableColumn('Пользователь'"));
    expect(desktop, contains("SpecialistTableColumn('Права'"));
    expect(dialogs, contains("value: 'admin'"));
    expect(dialogs, contains("value: 'foreman'"));
    expect(dialogs, contains("value: 'lawyer'"));
    expect(dialogs, contains("value: 'accountant'"));
    expect(dialogs, contains("role == 'foreman' ? objectId : null"));
  });

  test('invitation journal supports live statuses new link and revocation', () {
    final repository = source(
      'lib/features/company/data/company_invitation_repository.dart',
    );
    final desktop = source(
      'lib/features/company/presentation/desktop_company_management_screen.dart',
    );

    expect(repository, contains(".from('company_invitations')"));
    expect(repository, contains("status == 'pending'"));
    expect(repository, contains("return 'expired'"));
    expect(repository, contains('revokeInvitation'));
    expect(desktop, contains('recreateInvitation'));
    expect(desktop, contains('showDesktopInvitationLink'));
    expect(desktop, contains('revokeInvitation'));
    expect(desktop, contains("value: 'accepted'"));
    expect(desktop, contains("value: 'expired'"));
    expect(desktop, contains("value: 'revoked'"));
    expect(desktop, contains("label: const Text('Пригласить пользователя')"));
  });
}
