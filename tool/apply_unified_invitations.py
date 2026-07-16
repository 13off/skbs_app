from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


profile_path = Path('lib/screens/profile_screen.dart')
profile = profile_path.read_text(encoding='utf-8')
profile = replace_once(
    profile,
    "import '../features/legal/presentation/legal_member_invitation_screen.dart';\n",
    '',
    'specialist invitation import',
)
profile = replace_once(
    profile,
    """  void openSpecialistInvitation(BuildContext context) {
    if (profile.activeCompanyId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => LegalMemberInvitationScreen(
          companyId: profile.activeCompanyId,
        ),
      ),
    );
  }

""",
    '',
    'specialist invitation method',
)
profile = replace_once(
    profile,
    """            buildActionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Пригласить юриста или бухгалтера',
              subtitle:
                  'Создать ссылку для специалиста с отдельной ролью и рабочим разделом',
              onTap: () => openSpecialistInvitation(context),
            ),
""",
    '',
    'specialist invitation tile',
)
profile = replace_once(
    profile,
    """              subtitle:
                  'Приглашения, роли администраторов и назначение прорабов',
""",
    """              subtitle:
                  'Приглашения, роли и доступ всех пользователей компании',
""",
    'company management subtitle',
)
profile_path.write_text(profile, encoding='utf-8')

management_path = Path(
    'lib/features/company/presentation/company_management_screen.dart'
)
management = management_path.read_text(encoding='utf-8')
management = replace_once(
    management,
    """    role = widget.member?.role == 'admin' ? 'admin' : 'foreman';
    objectId = widget.member?.objectId.isNotEmpty == true
        ? widget.member!.objectId
        : (widget.objects.isEmpty ? null : widget.objects.first.id);
""",
    """    const allowedRoles = <String>{
      'admin',
      'foreman',
      'lawyer',
      'accountant',
    };
    final currentRole = widget.member?.role;
    role = currentRole != null && allowedRoles.contains(currentRole)
        ? currentRole
        : 'foreman';
    objectId = role == 'foreman'
        ? (widget.member?.objectId.isNotEmpty == true
              ? widget.member!.objectId
              : (widget.objects.isEmpty ? null : widget.objects.first.id))
        : null;
""",
    'member role initialization',
)
management = replace_once(
    management,
    """            items: const [
              DropdownMenuItem(value: 'foreman', child: Text('Прораб')),
              DropdownMenuItem(value: 'admin', child: Text('Администратор')),
            ],
            onChanged: isSaving
                ? null
                : (value) => setState(() => role = value ?? 'foreman'),
""",
    """            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Администратор')),
              DropdownMenuItem(value: 'foreman', child: Text('Прораб')),
              DropdownMenuItem(value: 'lawyer', child: Text('Юрист')),
              DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
            ],
            onChanged: isSaving
                ? null
                : (value) {
                    final nextRole = value ?? 'foreman';
                    setState(() {
                      role = nextRole;
                      if (role == 'foreman') {
                        final objectStillAvailable = widget.objects.any(
                          (item) => item.id == objectId,
                        );
                        if (!objectStillAvailable) {
                          objectId = widget.objects.isEmpty
                              ? null
                              : widget.objects.first.id;
                        }
                      } else {
                        objectId = null;
                      }
                    });
                  },
""",
    'unified role dropdown',
)
management_path.write_text(management, encoding='utf-8')

repository_path = Path('lib/features/company/data/company_repository.dart')
repository = repository_path.read_text(encoding='utf-8')
old_role_titles = """      case 'foreman':
        return 'Прораб';
      default:
"""
new_role_titles = """      case 'foreman':
        return 'Прораб';
      case 'lawyer':
        return 'Юрист';
      case 'accountant':
        return 'Бухгалтер';
      default:
"""
count = repository.count(old_role_titles)
if count != 2:
    raise SystemExit(f'company role labels: expected 2 matches, found {count}')
repository = repository.replace(old_role_titles, new_role_titles)
repository_path.write_text(repository, encoding='utf-8')

test_path = Path('test/unified_company_invitation_contract_test.dart')
test_path.write_text(
    """import 'dart:io';

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

  test('company form invites every supported role', () {
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
""",
    encoding='utf-8',
)
