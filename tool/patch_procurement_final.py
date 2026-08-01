from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected one match, found {count}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "supabase/functions/invite-company-member-core/index.ts",
    "async function findUserByEmail(\n  adminClient: ReturnType<typeof createClient>,\n  email: string,\n): Promise<User | null> {",
    "type UserAdminClient = {\n  auth: {\n    admin: {\n      listUsers: (options: {\n        page: number;\n        perPage: number;\n      }) => Promise<any>;\n    };\n  };\n};\n\nasync function findUserByEmail(\n  adminClient: UserAdminClient,\n  email: string,\n): Promise<User | null> {",
)

replace_once(
    "lib/features/developer/data/role_acceptance_repository.dart",
    """        RoleAcceptanceScenario(
          role: 'lawyer',
          title: 'Юрист',
          platform: 'LegalMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'legal.directory.view',
            'legal.documents.view',
            'legal.documents.edit',
            'legal.files.view',
            'legal.files.upload',
            'legal.matters.view',
            'legal.matters.edit',
            'legal.reports.view',
            'legal.reports.submit',
            'personal_data.audit.view',
            'personal_data.compliance.view',
            'personal_data.compliance.edit',
            'documents.templates.view',
            'objects.view',
            'reports.view',
            'notifications.center.view',
          ],
          forbiddenPermissions: <String>[
            'accounting.payments.view',
            'employees.edit',
            'attendance.edit',
            'tasks.edit',
            'recruitment.documents.edit',
            'system.roles.manage',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('legal_documents'),
            RoleAcceptanceProbe('legal_matters'),
            RoleAcceptanceProbe('objects'),
          ],
        ),
      ];""",
    """        RoleAcceptanceScenario(
          role: 'lawyer',
          title: 'Юрист',
          platform: 'LegalMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'legal.directory.view',
            'legal.documents.view',
            'legal.documents.edit',
            'legal.files.view',
            'legal.files.upload',
            'legal.matters.view',
            'legal.matters.edit',
            'legal.reports.view',
            'legal.reports.submit',
            'personal_data.audit.view',
            'personal_data.compliance.view',
            'personal_data.compliance.edit',
            'documents.templates.view',
            'objects.view',
            'reports.view',
            'notifications.center.view',
          ],
          forbiddenPermissions: <String>[
            'accounting.payments.view',
            'employees.edit',
            'attendance.edit',
            'tasks.edit',
            'recruitment.documents.edit',
            'system.roles.manage',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('legal_documents'),
            RoleAcceptanceProbe('legal_matters'),
            RoleAcceptanceProbe('objects'),
          ],
        ),
        RoleAcceptanceScenario(
          role: 'procurement',
          title: 'Снабженец',
          platform: 'ProcurementMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'procurement.requests.view',
            'procurement.requests.create',
            'procurement.requests.edit',
            'procurement.requests.approve',
            'procurement.suppliers.view',
            'procurement.suppliers.edit',
            'procurement.delivery.edit',
            'procurement.reports.view',
            'objects.view',
            'notifications.center.view',
          ],
          forbiddenPermissions: <String>[
            'employees.edit',
            'attendance.edit',
            'accounting.payments.edit',
            'recruitment.documents.edit',
            'legal.documents.edit',
            'system.roles.manage',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('procurement_requests'),
            RoleAcceptanceProbe('procurement_suppliers'),
            RoleAcceptanceProbe('objects'),
          ],
        ),
      ];""",
)
