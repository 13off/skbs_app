from pathlib import Path


def replace(path: str, old: str, new: str, *, count: int | None = None) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    found = text.count(old)
    expected = count if count is not None else 1
    if found != expected:
        raise RuntimeError(f"{path}: expected {expected} matches, found {found}")
    file.write_text(text.replace(old, new), encoding="utf-8")


replace(
    "lib/features/company/data/company_repository.dart",
    "      case 'hr':\n        return 'HR-менеджер';\n      default:",
    "      case 'hr':\n        return 'HR-менеджер';\n      case 'procurement':\n        return 'Снабженец';\n      default:",
    count=2,
)

replace(
    "lib/features/company/presentation/mobile_company_management_screen.dart",
    "      'accountant',\n      'hr',\n    };",
    "      'accountant',\n      'hr',\n      'procurement',\n    };",
)
replace(
    "lib/features/company/presentation/mobile_company_management_screen.dart",
    "                DropdownMenuItem(value: 'hr', child: Text('HR-менеджер')),\n              ],",
    "                DropdownMenuItem(value: 'hr', child: Text('HR-менеджер')),\n                DropdownMenuItem(\n                  value: 'procurement',\n                  child: Text('Снабженец'),\n                ),\n              ],",
)

replace(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    "      'accountant',\n      'hr',\n    };",
    "      'accountant',\n      'hr',\n      'procurement',\n    };",
)
replace(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    "                    : 'Одна форма для администратора, разработчика, прораба, юриста, бухгалтера и HR.',",
    "                    : 'Одна форма для администратора, разработчика, прораба, юриста, бухгалтера, снабженца и HR.',",
)
replace(
    "lib/features/company/presentation/desktop_company_user_dialogs.dart",
    "                        DropdownMenuItem(\n                          value: 'hr',\n                          child: Text('HR-менеджер'),\n                        ),\n                      ],",
    "                        DropdownMenuItem(\n                          value: 'hr',\n                          child: Text('HR-менеджер'),\n                        ),\n                        DropdownMenuItem(\n                          value: 'procurement',\n                          child: Text('Снабженец'),\n                        ),\n                      ],",
)

replace(
    "supabase/functions/invite-company-member-core/index.ts",
    '      "accountant",\n      "hr",\n    ]);',
    '      "accountant",\n      "hr",\n      "procurement",\n    ]);',
)
