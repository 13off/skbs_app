from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise SystemExit(f"Pattern not found: {label} in {path}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def replace_all(path: str, old: str, new: str, minimum: int, label: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f"Pattern count {count} < {minimum}: {label} in {path}")
    file.write_text(text.replace(old, new), encoding="utf-8")


replace_once(
    "lib/features/role_preview/role_preview_screen.dart",
    """  void selectAccountant() {
    RolePreviewController.showAccountant();
  }

  Future<void> selectForeman""",
    """  void selectAccountant() {
    RolePreviewController.showAccountant();
  }

  void selectHr() {
    RolePreviewController.showHr();
  }

  Future<void> selectForeman""",
    "role preview HR method",
)
replace_once(
    "lib/features/role_preview/role_preview_screen.dart",
    """                  roleCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Бухгалтер',
                    subtitle:
                        'Начисления, выплаты, остатки, чеки и финансовые отчёты.',
                    selected: preview.isAccountantMode,
                    onTap: selectAccountant,
                  ),
                  const SizedBox(height: 8),""",
    """                  roleCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Бухгалтер',
                    subtitle:
                        'Начисления, выплаты, остатки, чеки и финансовые отчёты.',
                    selected: preview.isAccountantMode,
                    onTap: selectAccountant,
                  ),
                  roleCard(
                    icon: Icons.person_search_rounded,
                    title: 'HR-менеджер',
                    subtitle:
                        'Заявки кандидатов, документы, выезды и оформление.',
                    selected: preview.isHrMode,
                    onTap: selectHr,
                  ),
                  const SizedBox(height: 8),""",
    "role preview HR card",
)

replace_once(
    "lib/screens/main_screen.dart",
    "import '../features/legal/presentation/legal_main_screen.dart';\n",
    "import '../features/legal/presentation/legal_main_screen.dart';\nimport '../features/recruitment/presentation/recruitment_main_screen.dart';\n",
    "main HR import",
)
replace_once(
    "lib/screens/main_screen.dart",
    """    if (profile.isAccountant) {
      return AccountingMainScreen(profile: profile);
    }
    if (profile.isForeman) {""",
    """    if (profile.isAccountant) {
      return AccountingMainScreen(profile: profile);
    }
    if (profile.isHr) {
      return RecruitmentMainScreen(profile: profile);
    }
    if (profile.isForeman) {""",
    "main HR platform",
)

replace_once(
    "lib/data/app_data_sync.dart",
    "  legal,\n}",
    "  legal,\n  recruitment,\n}",
    "recruitment domain enum",
)
replace_once(
    "lib/data/app_data_sync.dart",
    """        AppDataDomain.notifications,
        AppDataDomain.legal,
      },""",
    """        AppDataDomain.notifications,
        AppDataDomain.legal,
        AppDataDomain.recruitment,
      },""",
    "full refresh recruitment",
)
replace_once(
    "lib/data/app_data_sync.dart",
    """          AppDataDomain.tasks,
          AppDataDomain.legal,
        };""",
    """          AppDataDomain.tasks,
          AppDataDomain.legal,
          AppDataDomain.recruitment,
        };""",
    "object refresh recruitment",
)
replace_once(
    "lib/data/app_data_sync.dart",
    """      case 'audit_log':
        return const <AppDataDomain>{AppDataDomain.legal};
      default:""",
    """      case 'audit_log':
        return const <AppDataDomain>{AppDataDomain.legal};
      case 'recruitment_applications':
        return const <AppDataDomain>{AppDataDomain.recruitment};
      default:""",
    "recruitment table mapping",
)

replace_all(
    "lib/features/company/data/company_repository.dart",
    """      case 'accountant':
        return 'Бухгалтер';
      default:""",
    """      case 'accountant':
        return 'Бухгалтер';
      case 'hr':
        return 'HR-менеджер';
      default:""",
    2,
    "company role titles",
)
replace_once(
    "lib/features/company/data/company_invitation_repository.dart",
    """      case 'accountant':
        return 'Бухгалтер';
      default:""",
    """      case 'accountant':
        return 'Бухгалтер';
      case 'hr':
        return 'HR-менеджер';
      default:""",
    "invitation role title",
)

replace_once(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    "const roles = <String>{'admin', 'foreman', 'lawyer', 'accountant'};",
    "const roles = <String>{'admin', 'foreman', 'lawyer', 'accountant', 'hr'};",
    "desktop allowed roles",
)
replace_once(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    "'Одна форма для администратора, прораба, юриста и бухгалтера.'",
    "'Одна форма для администратора, прораба, юриста, бухгалтера и HR.'",
    "desktop role description",
)
replace_once(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    """                        DropdownMenuItem(
                          value: 'accountant',
                          child: Text('Бухгалтер'),
                        ),
                      ],""",
    """                        DropdownMenuItem(
                          value: 'accountant',
                          child: Text('Бухгалтер'),
                        ),
                        DropdownMenuItem(
                          value: 'hr',
                          child: Text('HR-менеджер'),
                        ),
                      ],""",
    "desktop HR dropdown",
)

replace_once(
    "lib/features/company/presentation/mobile_company_management_screen.dart",
    """      'lawyer',
      'accountant',
    };""",
    """      'lawyer',
      'accountant',
      'hr',
    };""",
    "mobile allowed roles",
)
replace_once(
    "lib/features/company/presentation/mobile_company_management_screen.dart",
    """              DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
            ],""",
    """              DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
              DropdownMenuItem(value: 'hr', child: Text('HR-менеджер')),
            ],""",
    "mobile HR dropdown",
)

replace_once(
    "lib/features/company/presentation/desktop_company_management_screen.dart",
    """      case 'accountant':
        return const Color(0xFF48706A);
      default:""",
    """      case 'accountant':
        return const Color(0xFF48706A);
      case 'hr':
        return const Color(0xFF6A5D47);
      default:""",
    "desktop HR role color",
)
replace_once(
    "lib/features/company/presentation/desktop_company_management_screen.dart",
    ".where((item) => item.role == 'lawyer' || item.role == 'accountant')",
    ".where((item) =>\n            item.role == 'lawyer' ||\n            item.role == 'accountant' ||\n            item.role == 'hr')",
    "desktop specialist count",
)
replace_once(
    "lib/features/company/presentation/desktop_company_management_screen.dart",
    "label: 'Юрист и бухгалтер',",
    "label: 'Юрист, бухгалтер и HR',",
    "desktop specialist label",
)
replace_once(
    "lib/features/company/presentation/desktop_company_management_screen.dart",
    """                DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
              ],""",
    """                DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
                DropdownMenuItem(value: 'hr', child: Text('HR-менеджер')),
              ],""",
    "desktop HR role filter",
)

replace_once(
    "supabase/functions/invite-company-member-core/index.ts",
    'const allowedRoles = new Set(["admin", "foreman", "lawyer", "accountant"]);',
    'const allowedRoles = new Set(["admin", "foreman", "lawyer", "accountant", "hr"]);',
    "edge function allowed HR role",
)

replace_once(
    "test/admin_role_preview_contract_test.dart",
    """    final accountantView = admin.previewAs(role: 'accountant');
    final foremanView""",
    """    final accountantView = admin.previewAs(role: 'accountant');
    final hrView = admin.previewAs(role: 'hr');
    final foremanView""",
    "preview HR test setup",
)
replace_once(
    "test/admin_role_preview_contract_test.dart",
    """    expect(accountantView.isRolePreview, isTrue);
    expect(foremanView.role, 'foreman');""",
    """    expect(accountantView.isRolePreview, isTrue);
    expect(hrView.role, 'hr');
    expect(hrView.actualRole, 'admin');
    expect(foremanView.role, 'foreman');""",
    "preview HR assertions",
)
replace_once(
    "test/admin_role_preview_contract_test.dart",
    """    RolePreviewController.showAccountant();
    expect(RolePreviewController.state.value.role, 'accountant');
    expect(RolePreviewController.state.value.objectName, isEmpty);

    RolePreviewController.showAdmin();""",
    """    RolePreviewController.showAccountant();
    expect(RolePreviewController.state.value.role, 'accountant');
    expect(RolePreviewController.state.value.objectName, isEmpty);

    RolePreviewController.showHr();
    expect(RolePreviewController.state.value.role, 'hr');
    expect(RolePreviewController.state.value.objectName, isEmpty);

    RolePreviewController.showAdmin();""",
    "controller HR assertions",
)
replace_once(
    "test/admin_role_preview_contract_test.dart",
    """    expect(selector, contains("title: 'Бухгалтер'"));
    expect(selector, contains('onTap: selectAccountant'));""",
    """    expect(selector, contains("title: 'Бухгалтер'"));
    expect(selector, contains("title: 'HR-менеджер'"));
    expect(selector, contains('onTap: selectAccountant'));
    expect(selector, contains('onTap: selectHr'));""",
    "selector HR contract",
)
replace_once(
    "test/admin_role_preview_contract_test.dart",
    """    expect(main, contains('AccountingMainScreen(profile: profile)'));
    expect(main, contains("'К руководителю'"));""",
    """    expect(main, contains('AccountingMainScreen(profile: profile)'));
    expect(main, contains('RecruitmentMainScreen(profile: profile)'));
    expect(main, contains("'К руководителю'"));""",
    "main HR contract",
)
