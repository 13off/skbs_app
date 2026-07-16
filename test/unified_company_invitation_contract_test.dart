import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('profile exposes one company invitation entry point', () {
    final profile = source('lib/screens/profile_screen.dart');

    expect(profile, contains("title: 'Компания и пользователи'"));
    expect(
      RegExp("title: 'Компания и пользователи'").allMatches(profile).length,
      1,
    );
    expect(profile, isNot(contains('Пригласить юриста или бухгалтера')));
    expect(profile, isNot(contains('openSpecialistInvitation')));
    expect(profile, isNot(contains('legal_member_invitation_screen.dart')));
  });

  test('one company form invites every supported role', () {
    final screen = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );

    expect(screen, contains("label: 'Пригласить пользователя'"));
    expect(screen, contains("value: 'admin', child: Text('Администратор')"));
    expect(screen, contains("value: 'foreman', child: Text('Прораб')"));
    expect(screen, contains("value: 'lawyer', child: Text('Юрист')"));
    expect(screen, contains("value: 'accountant', child: Text('Бухгалтер')"));
    expect(screen, contains('allowedRoles.contains(currentRole)'));
  });

  test('object assignment remains exclusive to foreman', () {
    final screen = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );

    expect(screen, contains("if (role == 'foreman')"));
    expect(screen, contains("objectId: role == 'foreman' ? objectId : null"));
    expect(screen, contains("errorText = 'Для прораба нужно выбрать объект'"));
    expect(screen, contains('objectId = null;'));
  });

  test('company member list names specialist roles', () {
    final repository = source(
      'lib/features/company/data/company_repository.dart',
    );

    expect(RegExp("case 'lawyer':").allMatches(repository).length, 2);
    expect(RegExp("case 'accountant':").allMatches(repository).length, 2);
    expect(RegExp("return 'Юрист';").allMatches(repository).length, 2);
    expect(RegExp("return 'Бухгалтер';").allMatches(repository).length, 2);
  });
}
