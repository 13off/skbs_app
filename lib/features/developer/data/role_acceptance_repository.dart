import 'package:supabase_flutter/supabase_flutter.dart';

class RoleAcceptanceProbe {
  final String table;
  final String selectColumns;
  final String? objectColumn;

  const RoleAcceptanceProbe(
    this.table, {
    this.selectColumns = 'id',
    this.objectColumn,
  });
}

class RoleAcceptanceScenario {
  final String role;
  final String title;
  final String platform;
  final String objectScope;
  final List<String> requiredPermissions;
  final List<String> forbiddenPermissions;
  final List<RoleAcceptanceProbe> liveProbes;

  const RoleAcceptanceScenario({
    required this.role,
    required this.title,
    required this.platform,
    required this.objectScope,
    required this.requiredPermissions,
    required this.forbiddenPermissions,
    required this.liveProbes,
  });

  String get liveProbeTable => liveProbes.first.table;
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
  int get blocked => checks
      .where((item) => item.status == RoleAcceptanceStatus.blocked)
      .length;
}

abstract final class RoleAcceptanceRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const List<RoleAcceptanceScenario> scenarios =
      <RoleAcceptanceScenario>[
        RoleAcceptanceScenario(
          role: 'admin',
          title: 'Администратор',
          platform: 'ManagerMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'objects.view',
            'objects.create',
            'employees.view',
            'employees.create',
            'attendance.view',
            'attendance.edit',
            'tasks.view',
            'tasks.create',
            'accounting.payments.view',
            'accounting.payments.edit',
            'reports.view',
            'notifications.center.view',
            'notifications.settings.manage',
            'ai.use',
            'ai.actions.execute',
            'system.roles.manage',
            'system.audit.view',
            'system.recycle_bin.manage',
            'recruitment.applications.view',
            'legal.documents.view',
            'personal_data.compliance.view',
          ],
          forbiddenPermissions: <String>[],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('objects'),
            RoleAcceptanceProbe('employees'),
            RoleAcceptanceProbe('tasks'),
            RoleAcceptanceProbe('attendance'),
            RoleAcceptanceProbe('payments'),
          ],
        ),
        RoleAcceptanceScenario(
          role: 'developer',
          title: 'Разработчик',
          platform: 'DeveloperMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'system.settings.manage',
            'system.roles.manage',
            'system.audit.view',
            'system.recycle_bin.manage',
            'objects.view',
            'employees.view',
            'attendance.view',
            'tasks.view',
            'accounting.payments.view',
            'documents.templates.edit',
            'notifications.settings.manage',
            'ai.use',
            'ai.actions.execute',
            'personal_data.compliance.edit',
          ],
          forbiddenPermissions: <String>[],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe(
              'company_task_policies',
              selectColumns: 'company_id',
            ),
            RoleAcceptanceProbe('objects'),
            RoleAcceptanceProbe('employees'),
            RoleAcceptanceProbe('tasks'),
            RoleAcceptanceProbe('payments'),
          ],
        ),
        RoleAcceptanceScenario(
          role: 'foreman',
          title: 'Прораб',
          platform: 'ForemanMainScreen',
          objectScope: 'Только назначенный объект',
          requiredPermissions: <String>[
            'objects.view',
            'employees.view',
            'attendance.view',
            'attendance.edit',
            'tasks.view',
            'tasks.create',
            'tasks.edit',
            'tasks.assignees.manage',
            'tasks.photos.manage',
            'goals.view',
            'notifications.center.view',
            'ai.use',
            'recruitment.mobilization.view',
          ],
          forbiddenPermissions: <String>[
            'accounting.payments.view',
            'accounting.payments.edit',
            'employees.create',
            'employees.delete',
            'attendance.delete',
            'recruitment.documents.view',
            'personal_data.compliance.view',
            'system.roles.manage',
            'system.audit.view',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe(
              'objects',
              selectColumns: 'id, name',
              objectColumn: 'name',
            ),
            RoleAcceptanceProbe(
              'tasks',
              selectColumns: 'id, object_name',
              objectColumn: 'object_name',
            ),
            RoleAcceptanceProbe(
              'employees',
              selectColumns: 'id, object_name',
              objectColumn: 'object_name',
            ),
          ],
        ),
        RoleAcceptanceScenario(
          role: 'hr',
          title: 'HR-менеджер',
          platform: 'RecruitmentMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'recruitment.applications.view',
            'recruitment.applications.edit',
            'recruitment.documents.view',
            'recruitment.documents.edit',
            'recruitment.messages.view',
            'recruitment.messages.send',
            'recruitment.mobilization.view',
            'recruitment.mobilization.edit',
            'documents.templates.view',
            'documents.templates.edit',
            'employees.view',
            'notifications.center.view',
            'personal_data.compliance.view',
            'ai.use',
          ],
          forbiddenPermissions: <String>[
            'accounting.payments.view',
            'attendance.edit',
            'tasks.edit',
            'legal.documents.edit',
            'system.roles.manage',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('recruitment_applications'),
            RoleAcceptanceProbe('recruitment_documents'),
            RoleAcceptanceProbe('employees'),
          ],
        ),
        RoleAcceptanceScenario(
          role: 'accountant',
          title: 'Бухгалтер',
          platform: 'AccountingMainScreen',
          objectScope: 'Вся компания',
          requiredPermissions: <String>[
            'accounting.attendance.view',
            'accounting.directory.view',
            'accounting.payments.view',
            'accounting.payments.edit',
            'accounting.receipts.view',
            'accounting.receipts.edit',
            'accounting.reports.export',
            'employees.view',
            'objects.view',
            'reports.view',
            'reports.export',
            'notifications.center.view',
            'recruitment.mobilization.view',
          ],
          forbiddenPermissions: <String>[
            'employees.edit',
            'attendance.edit',
            'tasks.edit',
            'recruitment.documents.edit',
            'legal.documents.edit',
            'system.roles.manage',
          ],
          liveProbes: <RoleAcceptanceProbe>[
            RoleAcceptanceProbe('payments'),
            RoleAcceptanceProbe('attendance'),
            RoleAcceptanceProbe('employees'),
          ],
        ),
        RoleAcceptanceScenario(
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

  static Future<RoleAcceptanceCheck> _probe(
    RoleAcceptanceProbe probe, {
    required String companyId,
    required String role,
    required String assignedObject,
  }) async {
    try {
      final List<dynamic> rows = await _client
          .from(probe.table)
          .select(probe.selectColumns)
          .eq('company_id', companyId)
          .limit(50);

      if (role == 'foreman' && probe.objectColumn != null) {
        if (assignedObject.isEmpty) {
          return RoleAcceptanceCheck(
            title: 'RLS: ${probe.table}',
            description: 'Проверка объектной границы без клиентского фильтра.',
            status: RoleAcceptanceStatus.failed,
            result: 'Прорабу не назначен объект',
          );
        }
        final foreignRows = rows.where((value) {
          if (value is! Map) return true;
          final row = Map<String, dynamic>.from(value);
          return _text(row[probe.objectColumn!]) != assignedObject;
        }).length;
        if (foreignRows > 0) {
          return RoleAcceptanceCheck(
            title: 'RLS: ${probe.table}',
            description: 'Проверка объектной границы без клиентского фильтра.',
            status: RoleAcceptanceStatus.failed,
            result:
                'Нарушение: сервер вернул строк с другого объекта: $foreignRows',
          );
        }
      }

      return RoleAcceptanceCheck(
        title: 'RLS: ${probe.table}',
        description: role == 'foreman' && probe.objectColumn != null
            ? 'SELECT без объектного фильтра обязан вернуть только назначенный объект.'
            : 'Минимальный SELECT через пользовательский JWT и активную компанию.',
        status: RoleAcceptanceStatus.passed,
        result: 'Read-only запрос выполнен · строк проверено: ${rows.length}',
      );
    } catch (error) {
      return RoleAcceptanceCheck(
        title: 'RLS: ${probe.table}',
        description: 'Минимальный SELECT через пользовательский JWT.',
        status: RoleAcceptanceStatus.failed,
        result: error.toString().replaceFirst(
          'PostgrestException(message: ',
          '',
        ),
      );
    }
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
        status: live
            ? RoleAcceptanceStatus.passed
            : RoleAcceptanceStatus.blocked,
        result: live
            ? 'Вход выполнен ролью «${scenario.title}»'
            : 'Сейчас серверная роль: $serverRole. Для live-приёмки нужен отдельный вход ролью ${scenario.role}.',
      ),
      RoleAcceptanceCheck(
        title: 'Активная компания',
        description:
            'Все запросы обязаны оставаться внутри выбранной компании.',
        status: companyId.isNotEmpty
            ? RoleAcceptanceStatus.passed
            : RoleAcceptanceStatus.failed,
        result: companyId.isNotEmpty
            ? 'Компания определена'
            : 'Компания не выбрана',
      ),
    ];

    if (!live) {
      checks.add(
        const RoleAcceptanceCheck(
          title: 'Live-права и RLS',
          description:
              'Режим просмотра роли не должен подменять серверную идентичность.',
          status: RoleAcceptanceStatus.blocked,
          result:
              'Проверка намеренно не имитируется. Войди реальной тестовой учётной записью этой роли.',
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
          description: 'Критическое разрешение для роли ${scenario.role}.',
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
          result: allowed
              ? 'Нарушение: сервер разрешил действие'
              : 'Запрет подтверждён',
        ),
      );
    }

    if (scenario.role == 'foreman') {
      checks.add(
        RoleAcceptanceCheck(
          title: 'Назначенный объект',
          description:
              'Прораб обязан работать только в границах назначенного объекта.',
          status: assignedObject.isNotEmpty
              ? RoleAcceptanceStatus.passed
              : RoleAcceptanceStatus.failed,
          result: assignedObject.isEmpty
              ? 'Прорабу не назначен объект'
              : 'Объект: $assignedObject',
        ),
      );
    }

    for (final probe in scenario.liveProbes) {
      checks.add(
        await _probe(
          probe,
          companyId: companyId,
          role: scenario.role,
          assignedObject: assignedObject,
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
