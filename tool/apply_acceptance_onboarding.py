from pathlib import Path
import json


def write(path: str, content: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content.strip() + "\n", encoding="utf-8")


write(
    "lib/features/company/data/company_setup_repository.dart",
    r'''
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';
import '../../compliance/data/company_compliance_repository.dart';
import 'company_repository.dart';

enum CompanySetupAction {
  company,
  objects,
  team,
  employees,
  tasks,
  attendance,
  notifications,
  compliance,
}

class CompanySetupStep {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final bool required;
  final CompanySetupAction action;

  const CompanySetupStep({
    required this.id,
    required this.title,
    required this.description,
    required this.completed,
    required this.required,
    required this.action,
  });
}

class CompanySetupProgress {
  final String companyId;
  final String companyName;
  final List<CompanySetupStep> steps;

  const CompanySetupProgress({
    required this.companyId,
    required this.companyName,
    required this.steps,
  });

  List<CompanySetupStep> get requiredSteps =>
      steps.where((step) => step.required).toList(growable: false);

  int get completedRequired =>
      requiredSteps.where((step) => step.completed).length;

  bool get coreCompleted =>
      requiredSteps.isNotEmpty && completedRequired == requiredSteps.length;

  double get progress => requiredSteps.isEmpty
      ? 0
      : completedRequired / requiredSteps.length;

  CompanySetupStep? get nextRequiredStep {
    for (final step in requiredSteps) {
      if (!step.completed) return step;
    }
    return null;
  }
}

abstract final class CompanySetupRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<bool> _safeProbe(Future<List<dynamic>> Function() query) async {
    try {
      final rows = await query();
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _notificationCenterAvailable() async {
    try {
      final result = await _client.rpc<dynamic>(
        'get_my_notification_control_center',
      );
      return result is Map;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _complianceStarted(String companyId) async {
    try {
      final snapshot = await CompanyComplianceRepository.fetchSnapshot(companyId);
      return snapshot.employer.companyName.trim().isNotEmpty ||
          snapshot.gate.completedEvidenceCount > 0 ||
          snapshot.employer.legalDocumentsApproved;
    } catch (_) {
      return false;
    }
  }

  static Future<CompanySetupProgress> fetch(AppUserProfile profile) async {
    final companyId = profile.activeCompanyId.trim();
    if (companyId.isEmpty) throw Exception('Активная компания не выбрана');

    final dashboard = await CompanyRepository.fetchDashboard(companyId);
    final results = await Future.wait<bool>([
      _safeProbe(
        () async => await _client
            .from('employees')
            .select('id')
            .eq('company_id', companyId)
            .eq('is_active', true)
            .isFilter('archived_at', null)
            .limit(1),
      ),
      _safeProbe(
        () async => await _client
            .from('tasks')
            .select('id')
            .eq('company_id', companyId)
            .eq('is_draft', false)
            .isFilter('deleted_at', null)
            .limit(1),
      ),
      _safeProbe(
        () async => await _client
            .from('attendance')
            .select('id')
            .eq('company_id', companyId)
            .isFilter('deleted_at', null)
            .limit(1),
      ),
      _notificationCenterAvailable(),
      _complianceStarted(companyId),
    ]);

    final hasObject = dashboard.objects.isNotEmpty;
    final hasAssignedForeman = dashboard.members.any(
      (member) =>
          member.isActive &&
          member.role == 'foreman' &&
          member.objectId.trim().isNotEmpty,
    );

    return CompanySetupProgress(
      companyId: companyId,
      companyName: dashboard.company.name,
      steps: <CompanySetupStep>[
        CompanySetupStep(
          id: 'company',
          title: 'Рабочее пространство создано',
          description: 'Компания активна, а текущий пользователь имеет доступ.',
          completed: dashboard.company.id.isNotEmpty,
          required: true,
          action: CompanySetupAction.company,
        ),
        CompanySetupStep(
          id: 'objects',
          title: 'Добавьте первый объект',
          description: 'Объект связывает сотрудников, табель, задачи и отчёты.',
          completed: hasObject,
          required: true,
          action: CompanySetupAction.objects,
        ),
        CompanySetupStep(
          id: 'team',
          title: 'Пригласите и назначьте прораба',
          description: 'У прораба должна быть активная роль и назначенный объект.',
          completed: hasAssignedForeman,
          required: true,
          action: CompanySetupAction.team,
        ),
        CompanySetupStep(
          id: 'employees',
          title: 'Добавьте сотрудников',
          description: 'Нужна хотя бы одна активная карточка сотрудника на объекте.',
          completed: results[0],
          required: true,
          action: CompanySetupAction.employees,
        ),
        CompanySetupStep(
          id: 'tasks',
          title: 'Создайте первую рабочую задачу',
          description: 'Опубликованная задача проверяет объект, исполнителей и ограничения.',
          completed: results[1],
          required: true,
          action: CompanySetupAction.tasks,
        ),
        CompanySetupStep(
          id: 'attendance',
          title: 'Заполните первый табель',
          description: 'Сохраните хотя бы одну рабочую отметку через штатный экран.',
          completed: results[2],
          required: true,
          action: CompanySetupAction.attendance,
        ),
        CompanySetupStep(
          id: 'notifications',
          title: 'Проверьте центр уведомлений',
          description: 'Колокольчик и настройки должны открываться для текущей компании.',
          completed: results[3],
          required: true,
          action: CompanySetupAction.notifications,
        ),
        CompanySetupStep(
          id: 'compliance',
          title: 'Заполните профиль работодателя',
          description: 'Реквизиты и доказательства нужны до работы с реальными документами.',
          completed: results[4],
          required: false,
          action: CompanySetupAction.compliance,
        ),
      ],
    );
  }
}
''',
)

write(
    "lib/features/company/presentation/company_setup_screen.dart",
    r'''
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/notification_control_center_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../compliance/presentation/company_compliance_screen.dart';
import '../../developer/presentation/developer_demo_center_screen.dart';
import '../data/company_setup_repository.dart';
import 'company_management_screen.dart';

class CompanySetupScreen extends StatefulWidget {
  final AppUserProfile profile;

  const CompanySetupScreen({super.key, required this.profile});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  late Future<CompanySetupProgress> progressFuture;

  @override
  void initState() {
    super.initState();
    progressFuture = CompanySetupRepository.fetch(widget.profile);
  }

  void refresh() {
    setState(() {
      progressFuture = CompanySetupRepository.fetch(widget.profile);
    });
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) refresh();
  }

  Future<void> openStep(CompanySetupStep step) async {
    final profile = widget.profile;
    switch (step.action) {
      case CompanySetupAction.company:
      case CompanySetupAction.objects:
      case CompanySetupAction.team:
        await open(
          CompanyManagementScreen(companyId: profile.activeCompanyId),
        );
      case CompanySetupAction.employees:
        await open(
          AdaptiveEmployeesScreen(
            profile: profile,
            selectedObjectName: null,
          ),
        );
      case CompanySetupAction.tasks:
        await open(TasksScreen(profile: profile, selectedObjectName: null));
      case CompanySetupAction.attendance:
        await open(
          AdaptiveTimesheetScreen(
            profile: profile,
            selectedObjectName: null,
          ),
        );
      case CompanySetupAction.notifications:
        await open(const NotificationControlCenterScreen());
      case CompanySetupAction.compliance:
        await open(CompanyComplianceScreen(profile: profile));
    }
  }

  Widget progressCard(CompanySetupProgress progress) {
    final percent = (progress.progress * 100).round();
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: progress.coreCompleted
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  progress.coreCompleted
                      ? Icons.verified_rounded
                      : Icons.rocket_launch_outlined,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.companyName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.coreCompleted
                          ? 'Компания готова к базовой работе'
                          : 'Следующий шаг: ${progress.nextRequiredStep?.title ?? 'проверить настройки'}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.progress,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${progress.completedRequired} из ${progress.requiredSteps.length} обязательных шагов',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget stepCard(CompanySetupStep step) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => openStep(step),
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: step.completed
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  step.completed
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!step.required)
                          Text(
                            'РЕКОМЕНДУЕТСЯ',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Запуск компании',
      showBackButton: true,
      subtitle: 'Пошаговая настройка первого рабочего контура',
      headerTrailing: IconButton(
        tooltip: 'Проверить снова',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<CompanySetupProgress>(
        future: progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return PremiumWorkCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Не удалось проверить запуск компании: ${snapshot.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }

          final progress = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              progressCard(progress),
              const SizedBox(height: 16),
              ...progress.steps.map(stepCard),
              const SizedBox(height: 6),
              PremiumPressable(
                onTap: () => open(const DeveloperDemoCenterScreen()),
                borderRadius: BorderRadius.circular(22),
                child: const PremiumWorkCard(
                  radius: 22,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Открыть безопасное демо на полностью вымышленных данных',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Проверка только читает состояние компании. Она не создаёт сотрудников, задачи, табель или выплаты автоматически.',
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
              ),
            ],
          );
        },
      ),
    );
  }
}
''',
)

write(
    "lib/features/company/presentation/company_setup_nudge.dart",
    r'''
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../data/company_setup_repository.dart';
import 'company_setup_screen.dart';

class CompanySetupNudge extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const CompanySetupNudge({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<CompanySetupNudge> createState() => _CompanySetupNudgeState();
}

class _CompanySetupNudgeState extends State<CompanySetupNudge> {
  static const String revision = 'v1';
  bool checking = false;

  bool get enabled {
    final role = widget.profile.actualRole;
    return !widget.profile.isRolePreview &&
        (role == 'admin' || role == 'developer') &&
        widget.profile.activeCompanyId.trim().isNotEmpty;
  }

  String get storageKey =>
      'company_setup_nudge:$revision:${widget.profile.activeCompanyId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void didUpdateWidget(covariant CompanySetupNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.actualRole != widget.profile.actualRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) => check());
    }
  }

  Future<void> check() async {
    if (!enabled || checking || !mounted) return;
    checking = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(storageKey) == true) return;
      final progress = await CompanySetupRepository.fetch(widget.profile);
      if (!mounted || progress.coreCompleted) {
        await preferences.setBool(storageKey, true);
        return;
      }
      await preferences.setBool(storageKey, true);
      if (!mounted) return;
      final openSetup = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Завершите запуск компании'),
          content: Text(
            '${progress.completedRequired} из ${progress.requiredSteps.length} шагов готово.\n\n'
            'Следующий шаг: ${progress.nextRequiredStep?.title ?? 'проверить настройки'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Позже'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Открыть запуск'),
            ),
          ],
        ),
      );
      if (openSetup == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CompanySetupScreen(profile: widget.profile),
          ),
        );
      }
    } catch (_) {
      // Первый запуск не должен блокировать рабочую платформу.
    } finally {
      checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
''',
)

write(
    "lib/features/developer/data/role_acceptance_repository.dart",
    r'''
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
            result: 'Нарушение: сервер вернул строк с другого объекта: $foreignRows',
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
        result: error.toString().replaceFirst('PostgrestException(message: ', ''),
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
''',
)

# Patch main platform with a first-launch nudge.
main_path = Path("lib/main_screen.dart")
main = main_path.read_text(encoding="utf-8")
import_anchor = "import '../features/accounting/presentation/accounting_main_screen.dart';\n"
if import_anchor not in main:
    raise SystemExit("main import anchor not found")
main = main.replace(
    import_anchor,
    import_anchor + "import '../features/company/presentation/company_setup_nudge.dart';\n",
    1,
)
old_platform = """        if (!profile.isRolePreview) return platform;
        return _RolePreviewFrame(profile: profile, child: platform);
"""
new_platform = """        final content = !profile.isRolePreview
            ? platform
            : _RolePreviewFrame(profile: profile, child: platform);
        return CompanySetupNudge(profile: profile, child: content);
"""
if old_platform not in main:
    raise SystemExit("main platform anchor not found")
main = main.replace(old_platform, new_platform, 1)
main_path.write_text(main, encoding="utf-8")

# Add permanent setup entry to profile.
profile_path = Path("lib/screens/profile_screen.dart")
profile = profile_path.read_text(encoding="utf-8")
profile_import = "import '../features/company/presentation/company_management_screen.dart';\n"
if profile_import not in profile:
    raise SystemExit("profile import anchor not found")
profile = profile.replace(
    profile_import,
    profile_import + "import '../features/company/presentation/company_setup_screen.dart';\n",
    1,
)
management_anchor = """            sectionTitle(context, 'Управление компанией'),
            actionTile(
              context,
              icon: Icons.gavel_rounded,
"""
management_replacement = """            sectionTitle(context, 'Управление компанией'),
            actionTile(
              context,
              icon: Icons.rocket_launch_outlined,
              title: 'Запуск компании',
              subtitle:
                  'Объект, прораб, сотрудники, первая задача, табель и уведомления',
              onTap: () => open(
                context,
                CompanySetupScreen(profile: profile),
              ),
            ),
            actionTile(
              context,
              icon: Icons.gavel_rounded,
"""
if management_anchor not in profile:
    raise SystemExit("profile management anchor not found")
profile = profile.replace(management_anchor, management_replacement, 1)
profile_path.write_text(profile, encoding="utf-8")

# Add setup entry to developer system.
system_path = Path("lib/features/developer/presentation/developer_system_screen.dart")
system = system_path.read_text(encoding="utf-8")
system_import = "import '../../company/presentation/company_management_screen.dart';\n"
if system_import not in system:
    raise SystemExit("developer system import anchor not found")
system = system.replace(
    system_import,
    system_import + "import '../../company/presentation/company_setup_screen.dart';\n",
    1,
)
readiness_anchor = """          actionCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Ролевая приёмка',
"""
setup_card = """          actionCard(
            context,
            icon: Icons.rocket_launch_outlined,
            title: 'Запуск компании',
            subtitle:
                'Проверить первый объект, назначенного прораба, сотрудников, задачу, табель и уведомления.',
            onTap: () => open(
              context,
              CompanySetupScreen(profile: profile),
            ),
          ),
          actionCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Ролевая приёмка',
"""
if readiness_anchor not in system:
    raise SystemExit("developer role acceptance anchor not found")
system = system.replace(readiness_anchor, setup_card, 1)
system_path.write_text(system, encoding="utf-8")

# Expand readiness with core modules, governance, notifications and operational AI.
readiness_path = Path("lib/features/developer/presentation/developer_readiness_screen.dart")
readiness = readiness_path.read_text(encoding="utf-8")
readiness_import = "import '../data/developer_policy_repository.dart';\n"
if readiness_import not in readiness:
    raise SystemExit("readiness import anchor not found")
readiness = readiness.replace(
    readiness_import,
    "import '../data/data_governance_repository.dart';\n" + readiness_import,
    1,
)
rls_anchor = """      await check(
        'Ограничения компании и объектов',
"""
extra_checks = """      await check(
        'Ключевые рабочие таблицы',
        'Проверяет сотрудников, табель, задачи, выплаты и уведомления одним пользовательским JWT.',
        () async {
          if (companyId.isEmpty) throw Exception('Активная компания не выбрана');
          await Future.wait<dynamic>([
            client.from('employees').select('id').eq('company_id', companyId).limit(1),
            client.from('attendance').select('id').eq('company_id', companyId).limit(1),
            client.from('tasks').select('id').eq('company_id', companyId).limit(1),
            client.from('payments').select('id').eq('company_id', companyId).limit(1),
            client.from('app_notifications').select('id').eq('company_id', companyId).limit(1),
          ]);
        },
      ),
      await check(
        'Корзина и общий журнал',
        'Проверяет защищённый read-only центр контроля данных.',
        () async {
          await DataGovernanceRepository.fetchCenter(limit: 1);
        },
      ),
      await check(
        'Оперативная аналитика ИИ',
        'Выполняет безопасную недельную сводку без создания или изменения данных.',
        () async {
          if (companyId.isEmpty) throw Exception('Активная компания не выбрана');
          final response = await client.functions.invoke(
            'ai-operational-insights',
            body: <String, dynamic>{
              'mode': 'chat',
              'company_id': companyId,
              'object_name': widget.profile.objectName.trim(),
              'date': '${now.year}-$month-${now.day.toString().padLeft(2, '0')}',
              'prompt': 'Сделай недельную сводку по объекту',
            },
          );
          if (response.status < 200 || response.status >= 300) {
            throw Exception('Edge Function ответила HTTP ${response.status}');
          }
          final data = response.data;
          if (data is! Map || data['error'] != null) {
            throw Exception(
              data is Map ? data['error'] ?? 'Некорректный ответ' : 'Некорректный ответ',
            );
          }
        },
      ),
      await check(
        'Ограничения компании и объектов',
"""
if rls_anchor not in readiness:
    raise SystemExit("readiness RLS anchor not found")
readiness = readiness.replace(rls_anchor, extra_checks, 1)
readiness_path.write_text(readiness, encoding="utf-8")

# Update the machine role matrix with multiple probes and richer critical contracts.
matrix_path = Path("config/role-capability-matrix.json")
matrix = json.loads(matrix_path.read_text(encoding="utf-8"))
matrix["schema_version"] = 3
matrix["principles"]["live_acceptance_uses_multiple_rls_probes"] = True
matrix["principles"]["foreman_scope_is_verified_without_client_filter"] = True
scenario_source = {
    "admin": {
        "required": ["objects.view", "employees.view", "attendance.view", "tasks.view", "accounting.payments.view", "reports.view", "notifications.center.view", "ai.use", "system.roles.manage", "system.audit.view"],
        "forbidden": [],
        "probes": ["objects", "employees", "tasks", "attendance", "payments"],
    },
    "developer": {
        "required": ["system.settings.manage", "system.roles.manage", "system.audit.view", "system.recycle_bin.manage", "objects.view", "employees.view", "tasks.view", "accounting.payments.view", "ai.use"],
        "forbidden": [],
        "probes": ["company_task_policies", "objects", "employees", "tasks", "payments"],
    },
    "foreman": {
        "required": ["objects.view", "employees.view", "attendance.view", "attendance.edit", "tasks.view", "tasks.create", "tasks.edit", "tasks.photos.manage", "notifications.center.view", "ai.use"],
        "forbidden": ["accounting.payments.view", "employees.create", "employees.delete", "attendance.delete", "recruitment.documents.view", "system.roles.manage", "system.audit.view"],
        "probes": ["objects", "tasks", "employees"],
    },
    "hr": {
        "required": ["recruitment.applications.view", "recruitment.documents.edit", "recruitment.messages.send", "recruitment.mobilization.edit", "documents.templates.view", "employees.view", "notifications.center.view", "ai.use"],
        "forbidden": ["accounting.payments.view", "attendance.edit", "tasks.edit", "legal.documents.edit", "system.roles.manage"],
        "probes": ["recruitment_applications", "recruitment_documents", "employees"],
    },
    "accountant": {
        "required": ["accounting.attendance.view", "accounting.payments.view", "accounting.payments.edit", "accounting.receipts.view", "accounting.receipts.edit", "employees.view", "objects.view", "reports.view", "notifications.center.view"],
        "forbidden": ["employees.edit", "attendance.edit", "tasks.edit", "recruitment.documents.edit", "legal.documents.edit", "system.roles.manage"],
        "probes": ["payments", "attendance", "employees"],
    },
    "lawyer": {
        "required": ["legal.documents.view", "legal.documents.edit", "legal.files.view", "legal.matters.view", "legal.reports.view", "personal_data.compliance.view", "documents.templates.view", "objects.view", "notifications.center.view"],
        "forbidden": ["accounting.payments.view", "employees.edit", "attendance.edit", "tasks.edit", "recruitment.documents.edit", "system.roles.manage"],
        "probes": ["legal_documents", "legal_matters", "objects"],
    },
}
for role in matrix["roles"]:
    contract = scenario_source[role["role"]]
    role["acceptance"] = {
        "live_probe_table": contract["probes"][0],
        "live_probe_tables": contract["probes"],
        "required_permissions": contract["required"],
        "forbidden_permissions": contract["forbidden"],
    }
    if role["role"] == "foreman":
        role["acceptance"]["requires_assigned_object"] = True
        role["acceptance"]["probe_without_client_object_filter"] = True
matrix_path.write_text(json.dumps(matrix, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

write(
    "config/acceptance-scenarios.json",
    json.dumps(
        {
            "schema_version": 1,
            "mode": "production_safe",
            "automatic_writes": False,
            "mobile_release": False,
            "scenarios": [
                {"id": "first_launch", "title": "Создание компании и запуск", "required": True},
                {"id": "object_team", "title": "Объект и назначенный прораб", "required": True},
                {"id": "employee_attendance", "title": "Сотрудник и первая отметка табеля", "required": True},
                {"id": "task_photos", "title": "Задача, исполнители и фото", "required": True},
                {"id": "payment_receipt", "title": "Выплата и подтверждающий чек", "required": True},
                {"id": "recycle_restore", "title": "Корзина и восстановление", "required": True},
                {"id": "permission_override", "title": "Изменение права и серверный запрет", "required": True},
                {"id": "ai_confirmation", "title": "ИИ-черновик, подтверждение и аудит", "required": True},
                {"id": "notifications", "title": "Операционное уведомление без дублей", "required": True},
            ],
            "bad_states": [
                "double_submit",
                "slow_network",
                "connection_loss",
                "stale_cache",
                "concurrent_edit",
                "archived_object",
                "missing_rate",
                "missing_required_photos",
                "unauthorized_role",
            ],
            "rules": [
                "read_only_checks_never_create_work_records",
                "write_scenarios_require_manual_confirmation",
                "role_preview_is_not_live_acceptance",
                "production_personal_data_gate_remains_authoritative",
                "profession_directory_is_out_of_scope",
            ],
        },
        ensure_ascii=False,
        indent=2,
    ),
)

write(
    "docs/full-acceptance-runbook.md",
    r'''
# Полная приёмка AppСтрой

## Автоматическая часть

Перед публикацией обязательны Flutter analyzer, все regression-тесты, release web-build, SQL guard и Deno-check изменённых Edge Functions. После публикации отдельный smoke сверяет commit-маркер, PWA-файлы, российский API-прокси и JWT-защиту.

В приложении разработчик запускает:

1. **Готовность и диагностика** — сессия, компания, ключевые таблицы, ограничения, корзина, шаблоны и Edge Functions.
2. **Ролевую приёмку** — только под реальной тестовой учётной записью роли.
3. **Запуск компании** — объект, прораб, сотрудники, задача, табель и уведомления.
4. **Контроль табеля и выплат** — read-only поиск измеримых расхождений.

## Сквозные сценарии

Каждый сценарий выполняется в отдельной тестовой компании на маркированных тестовых данных.

- создать компанию;
- добавить объект;
- пригласить прораба и назначить объект;
- добавить сотрудника;
- заполнить табель;
- создать задачу, назначить исполнителя и прикрепить фото;
- закрыть задачу;
- добавить выплату и чек;
- подготовить ИИ-черновик и явно подтвердить действие;
- отправить запись в корзину и восстановить;
- изменить право роли и проверить фактический серверный запрет;
- дождаться операционного уведомления и убедиться, что дубль не появился.

## Негативные состояния

Обязательно проверить двойное нажатие, медленную сеть, потерю соединения, устаревший кеш, одновременное редактирование, архивный объект, пустую ставку, отсутствие обязательных фотографий и запрещённую роль.

Автоматическая приёмка не должна создавать, исправлять или удалять рабочие записи. Любое write-действие выполняется человеком в тестовой компании через обычную форму и явное подтверждение.

## Критерий пилота

Пилот разрешён, когда:

- обязательные шаги «Запуска компании» закрыты;
- каждая роль прошла live-приёмку отдельной учётной записью;
- автоматический CI и post-deploy smoke зелёные;
- нет критичных расхождений в едином контроле;
- production gate персональных документов либо подтверждён, либо реальные документы не используются;
- тестовая компания удалена или очищена через штатную корзину после проверки.
''',
)

write(
    "test/company_setup_acceptance_contract_test.dart",
    r'''
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('first launch has real progress and never seeds production data', () {
    final repository = source(
      'lib/features/company/data/company_setup_repository.dart',
    );
    final screen = source(
      'lib/features/company/presentation/company_setup_screen.dart',
    );
    final nudge = source(
      'lib/features/company/presentation/company_setup_nudge.dart',
    );

    expect(repository, contains("from('employees')"));
    expect(repository, contains("from('tasks')"));
    expect(repository, contains("from('attendance')"));
    expect(repository, contains('hasAssignedForeman'));
    expect(screen, contains("title: 'Запуск компании'"));
    expect(screen, contains('не создаёт сотрудников'));
    expect(nudge, contains('company_setup_nudge'));
    expect('$repository\n$screen\n$nudge', isNot(contains('.insert(')));
    expect('$repository\n$screen\n$nudge', isNot(contains('.update(')));
    expect('$repository\n$screen\n$nudge', isNot(contains('.delete(')));
  });

  test('setup remains reachable after the one-time prompt', () {
    final profile = source('lib/screens/profile_screen.dart');
    final system = source(
      'lib/features/developer/presentation/developer_system_screen.dart',
    );
    final main = source('lib/main_screen.dart');

    expect(profile, contains("title: 'Запуск компании'"));
    expect(system, contains("title: 'Запуск компании'"));
    expect(main, contains('CompanySetupNudge'));
  });

  test('role acceptance verifies multiple tables and foreman scope server-side', () {
    final repository = source(
      'lib/features/developer/data/role_acceptance_repository.dart',
    );
    final matrix = jsonDecode(
      source('config/role-capability-matrix.json'),
    ) as Map<String, dynamic>;

    expect(repository, contains('List<RoleAcceptanceProbe> liveProbes'));
    expect(repository, contains('for (final probe in scenario.liveProbes)'));
    expect(repository, contains('Нарушение: сервер вернул строк с другого объекта'));
    expect(repository, isNot(contains("query = query.eq('object_name'")));
    expect(matrix['schema_version'], 3);
    expect(
      (matrix['principles'] as Map)['foreman_scope_is_verified_without_client_filter'],
      isTrue,
    );
    for (final role in (matrix['roles'] as List<dynamic>).whereType<Map>()) {
      final acceptance = Map<String, dynamic>.from(role['acceptance'] as Map);
      expect((acceptance['live_probe_tables'] as List<dynamic>).length, greaterThan(1));
      expect((acceptance['required_permissions'] as List<dynamic>), isNotEmpty);
    }
  });

  test('readiness covers core modules governance and operational AI', () {
    final readiness = source(
      'lib/features/developer/presentation/developer_readiness_screen.dart',
    );

    expect(readiness, contains('Ключевые рабочие таблицы'));
    expect(readiness, contains("from('payments')"));
    expect(readiness, contains("from('app_notifications')"));
    expect(readiness, contains('DataGovernanceRepository.fetchCenter'));
    expect(readiness, contains("'ai-operational-insights'"));
  });

  test('machine acceptance checklist includes workflows and bad states', () {
    final checklist = jsonDecode(
      source('config/acceptance-scenarios.json'),
    ) as Map<String, dynamic>;

    expect(checklist['automatic_writes'], isFalse);
    expect(checklist['mobile_release'], isFalse);
    expect((checklist['scenarios'] as List<dynamic>).length, greaterThanOrEqualTo(9));
    expect((checklist['bad_states'] as List<dynamic>), contains('double_submit'));
    expect((checklist['bad_states'] as List<dynamic>), contains('concurrent_edit'));
    expect((checklist['rules'] as List<dynamic>), contains('profession_directory_is_out_of_scope'));
  });
}
''',
)

# Keep older acceptance contract compatible with schema v3 and multiple probes.
acceptance_test_path = Path("test/acceptance_demo_audit_contract_test.dart")
acceptance_test = acceptance_test_path.read_text(encoding="utf-8")
acceptance_test = acceptance_test.replace(
    "expect(matrix['schema_version'], 2);",
    "expect(matrix['schema_version'], 3);",
)
old_probe_expect = """      expect(acceptance['live_probe_table'].toString().trim(), isNotEmpty);
      expect(acceptance['required_permissions'], isA<List<dynamic>>());
"""
new_probe_expect = """      expect(acceptance['live_probe_table'].toString().trim(), isNotEmpty);
      expect((acceptance['live_probe_tables'] as List<dynamic>).length, greaterThan(1));
      expect(acceptance['required_permissions'], isA<List<dynamic>>());
"""
if old_probe_expect not in acceptance_test:
    raise SystemExit("acceptance test probe anchor not found")
acceptance_test = acceptance_test.replace(old_probe_expect, new_probe_expect, 1)
acceptance_test_path.write_text(acceptance_test, encoding="utf-8")
