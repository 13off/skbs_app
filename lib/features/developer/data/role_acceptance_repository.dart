import 'package:supabase_flutter/supabase_flutter.dart';

class RoleAcceptanceScenario {
  final String role;
  final String title;
  final String platform;
  final String objectScope;
  final List<String> requiredPermissions;
  final List<String> forbiddenPermissions;
  final String liveProbeTable;

  const RoleAcceptanceScenario({
    required this.role,
    required this.title,
    required this.platform,
    required this.objectScope,
    required this.requiredPermissions,
    required this.forbiddenPermissions,
    required this.liveProbeTable,
  });
}

enum RoleAcceptanceStatus { passed, failed, blocked }

class RoleAcceptanceCheck {
  final String title;
  final String description;
  final RoleAcceptanceStatus status;
  final String result;

  const RoleAcceptanceCheck({
    required this.title,
    required this.description,
    required this.status,
    required this.result,
  });
}

class RoleAcceptanceRun {
  final RoleAcceptanceScenario scenario;
  final String serverRole;
  final String companyId;
  final String assignedObject;
  final bool live;
  final List<RoleAcceptanceCheck> checks;

  const RoleAcceptanceRun({
    required this.scenario,
    required this.serverRole,
    required this.companyId,
    required this.assignedObject,
    required this.live,
    required this.checks,
  });

  int get passed =>
      checks.where((item) => item.status == RoleAcceptanceStatus.passed).length;
  int get failed =>
      checks.where((item) => item.status == RoleAcceptanceStatus.failed).length;
  int get blocked =>
      checks.where((item) => item.status == RoleAcceptanceStatus.blocked).length;
}

abstract final class RoleAcceptanceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const List<RoleAcceptanceScenario> scenarios = <RoleAcceptanceScenario>[
    RoleAcceptanceScenario(
      role: 'admin',
      title: 'Администратор',
      platform: 'ManagerMainScreen',
      objectScope: 'Вся компания',
      requiredPermissions: <String>[
        'recruitment.applications.view',
        'accounting.payments.view',
        'legal.documents.view',
        'personal_data.compliance.view',
      ],
      forbiddenPermissions: <String>[],
      liveProbeTable: 'objects',
    ),
    RoleAcceptanceScenario(
      role: 'developer',
      title: 'Разработчик',
      platform: 'DeveloperMainScreen',
      objectScope: 'Вся компания',
      requiredPermissions: <String>[
        'recruitment.applications.view',
        'accounting.payments.view',
        'legal.documents.view',
        'personal_data.compliance.edit',
      ],
      forbiddenPermissions: <String>[],
      liveProbeTable: 'company_task_policies',
    ),
    RoleAcceptanceScenario(
      role: 'foreman',
      title: 'Прораб',
      platform: 'ForemanMainScreen',
      objectScope: 'Только назначенный объект',
      requiredPermissions: <String>['recruitment.mobilization.view'],
      forbiddenPermissions: <String>[
        'accounting.payments.view',
        'recruitment.documents.view',
        'personal_data.compliance.view',
      ],
      liveProbeTable: 'tasks',
    ),
    RoleAcceptanceScenario(
      role: 'hr',
      title: 'HR-менеджер',
      platform: 'RecruitmentMainScreen',
      objectScope: 'Вся компания',
      requiredPermissions: <String>[
        'recruitment.applications.view',
        'recruitment.documents.edit',
        'recruitment.mobilization.edit',
        'personal_data.compliance.view',
      ],
      forbiddenPermissions: <String>[
        'accounting.payments.view',
        'legal.documents.edit',
      ],
      liveProbeTable: 'recruitment_applications',
    ),
    RoleAcceptanceScenario(
      role: 'accountant',
      title: 'Бухгалтер',
      platform: 'AccountingMainScreen',
      objectScope: 'Вся компания',
      requiredPermissions: <String>[
        'accounting.attendance.view',
        'accounting.payments.view',
        'accounting.payments.edit',
        'recruitment.mobilization.view',
      ],
      forbiddenPermissions: <String>[
        'recruitment.documents.edit',
        'legal.documents.edit',
      ],
      liveProbeTable: 'payments',
    ),
    RoleAcceptanceScenario(
      role: 'lawyer',
      title: 'Юрист',
      platform: 'LegalMainScreen',
      objectScope: 'Вся компания',
      requiredPermissions: <String>[
        'legal.documents.view',
        'legal.documents.edit',
        'personal_data.compliance.view',
        'personal_data.compliance.edit',
      ],
      forbiddenPermissions: <String>[
        'accounting.payments.view',
        'recruitment.documents.edit',
      ],
      liveProbeTable: 'legal_documents',
    ),
  ];

  static String normalizeRole(String value) {
    final clean = value.trim().toLowerCase();
    return clean == 'accounting' ? 'accountant' : clean;
  }

  static RoleAcceptanceScenario scenarioFor(String role) {
    final normalized = normalizeRole(role);
    return scenarios.firstWhere(
      (item) => item.role == normalized,
      orElse: () => scenarios.first,
    );
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    if (value is String) return value.trim();
    if (value is List && value.isNotEmpty) return _text(value.first);
    if (value is Map && value.isNotEmpty) return _text(value.values.first);
    return value.toString().trim();
  }

  static bool _boolean(dynamic value) {
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static Future<RoleAcceptanceRun> run({
    required String selectedRole,
    required String fallbackRole,
    required String fallbackCompanyId,
    required String fallbackObjectName,
  }) async {
    final scenario = scenarioFor(selectedRole);
    final rawRole = await _client.rpc('current_user_role');
    final rawCompany = await _client.rpc('current_user_company_id');
    final rawObject = await _client.rpc('current_user_object_name');
    final serverRole = normalizeRole(
      _text(rawRole).isEmpty ? fallbackRole : _text(rawRole),
    );
    final companyId = _text(rawCompany).isEmpty
        ? fallbackCompanyId.trim()
        : _text(rawCompany);
    final assignedObject = _text(rawObject).isEmpty
        ? fallbackObjectName.trim()
        : _text(rawObject);
    final live = serverRole == scenario.role;
    final checks = <RoleAcceptanceCheck>[
      RoleAcceptanceCheck(
        title: 'Серверная роль',
        description:
            'Проверяется реальная роль из JWT и активного членства, а не клиентский режим просмотра.',
        status: live ? RoleAcceptanceStatus.passed : RoleAcceptanceStatus.blocked,
        result: live
            ? 'Вход выполнен ролью «${scenario.title}»'
            : 'Сейчас серверная роль: $serverRole. Для live-приёмки нужен отдельный вход ролью ${scenario.role}.',
      ),
      RoleAcceptanceCheck(
        title: 'Активная компания',
        description: 'Все запросы обязаны оставаться внутри выбранной компании.',
        status: companyId.isNotEmpty
            ? RoleAcceptanceStatus.passed
            : RoleAcceptanceStatus.failed,
        result: companyId.isNotEmpty ? 'Компания определена' : 'Компания не выбрана',
      ),
    ];

    if (!live) {
      checks.add(
        const RoleAcceptanceCheck(
          title: 'Live-права и RLS',
          description:
              'Режим просмотра роли не должен подменять серверную идентичность.',
          status: RoleAcceptanceStatus.blocked,
          result: 'Проверка намеренно не имитируется. Войди реальной тестовой учётной записью этой роли.',
        ),
      );
      return RoleAcceptanceRun(
        scenario: scenario,
        serverRole: serverRole,
        companyId: companyId,
        assignedObject: assignedObject,
        live: false,
        checks: checks,
      );
    }

    for (final permission in scenario.requiredPermissions) {
      final value = await _client.rpc(
        'current_user_has_permission',
        params: <String, dynamic>{'p_permission_code': permission},
      );
      final allowed = _boolean(value);
      checks.add(
        RoleAcceptanceCheck(
          title: permission,
          description: 'Обязательное разрешение для роли ${scenario.role}.',
          status: allowed
              ? RoleAcceptanceStatus.passed
              : RoleAcceptanceStatus.failed,
          result: allowed ? 'Разрешено сервером' : 'Разрешение отсутствует',
        ),
      );
    }

    for (final permission in scenario.forbiddenPermissions) {
      final value = await _client.rpc(
        'current_user_has_permission',
        params: <String, dynamic>{'p_permission_code': permission},
      );
      final allowed = _boolean(value);
      checks.add(
        RoleAcceptanceCheck(
          title: 'Запрет: $permission',
          description: 'Роль не должна получать эту возможность.',
          status: allowed
              ? RoleAcceptanceStatus.failed
              : RoleAcceptanceStatus.passed,
          result: allowed ? 'Нарушение: сервер разрешил действие' : 'Запрет подтверждён',
        ),
      );
    }

    if (scenario.role == 'foreman') {
      checks.add(
        RoleAcceptanceCheck(
          title: 'Назначенный объект',
          description: 'Прораб обязан работать только в границах назначенного объекта.',
          status: assignedObject.isNotEmpty
              ? RoleAcceptanceStatus.passed
              : RoleAcceptanceStatus.failed,
          result: assignedObject.isEmpty
              ? 'Прорабу не назначен объект'
              : 'Объект: $assignedObject',
        ),
      );
    }

    try {
      var query = _client
          .from(scenario.liveProbeTable)
          .select('id')
          .eq('company_id', companyId);
      if (scenario.role == 'foreman' && assignedObject.isNotEmpty) {
        query = query.eq('object_name', assignedObject);
      }
      await query.limit(1);
      checks.add(
        RoleAcceptanceCheck(
          title: 'Data API и RLS',
          description:
              'Безопасный SELECT через пользовательский JWT: ${scenario.liveProbeTable}.',
          status: RoleAcceptanceStatus.passed,
          result: 'Read-only запрос выполнен',
        ),
      );
    } catch (error) {
      checks.add(
        RoleAcceptanceCheck(
          title: 'Data API и RLS',
          description:
              'Безопасный SELECT через пользовательский JWT: ${scenario.liveProbeTable}.',
          status: RoleAcceptanceStatus.failed,
          result: error.toString().replaceFirst('PostgrestException(message: ', ''),
        ),
      );
    }

    return RoleAcceptanceRun(
      scenario: scenario,
      serverRole: serverRole,
      companyId: companyId,
      assignedObject: assignedObject,
      live: true,
      checks: checks,
    );
  }
}
