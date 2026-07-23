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

  double get progress =>
      requiredSteps.isEmpty ? 0 : completedRequired / requiredSteps.length;

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

  static Future<bool> _allActiveEmployeesHaveRates(String companyId) async {
    try {
      final List<dynamic> rows = await _client
          .from('employees')
          .select('id, daily_rate')
          .eq('company_id', companyId)
          .eq('is_active', true)
          .isFilter('archived_at', null)
          .limit(5000);
      if (rows.isEmpty) return false;
      return rows.every((value) {
        if (value is! Map) return false;
        final rate = value['daily_rate'];
        return rate is num && rate > 0;
      });
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
      final snapshot = await CompanyComplianceRepository.fetchSnapshot(
        companyId,
      );
      return snapshot.employer.legalName.trim().isNotEmpty ||
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
      _allActiveEmployeesHaveRates(companyId),
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
          description:
              'У прораба должна быть активная роль и назначенный объект.',
          completed: hasAssignedForeman,
          required: true,
          action: CompanySetupAction.team,
        ),
        CompanySetupStep(
          id: 'employees',
          title: 'Добавьте сотрудников',
          description:
              'Нужна хотя бы одна активная карточка сотрудника на объекте.',
          completed: results[0],
          required: true,
          action: CompanySetupAction.employees,
        ),
        CompanySetupStep(
          id: 'rates',
          title: 'Назначьте дневные ставки',
          description:
              'У каждого активного сотрудника должна быть согласованная ставка больше нуля.',
          completed: results[1],
          required: true,
          action: CompanySetupAction.employees,
        ),
        CompanySetupStep(
          id: 'tasks',
          title: 'Создайте первую рабочую задачу',
          description:
              'Опубликованная задача проверяет объект, исполнителей и ограничения.',
          completed: results[2],
          required: true,
          action: CompanySetupAction.tasks,
        ),
        CompanySetupStep(
          id: 'attendance',
          title: 'Заполните первый табель',
          description:
              'Сохраните хотя бы одну рабочую отметку через штатный экран.',
          completed: results[3],
          required: true,
          action: CompanySetupAction.attendance,
        ),
        CompanySetupStep(
          id: 'notifications',
          title: 'Проверьте центр уведомлений',
          description:
              'Колокольчик и настройки должны открываться для текущей компании.',
          completed: results[4],
          required: true,
          action: CompanySetupAction.notifications,
        ),
        CompanySetupStep(
          id: 'compliance',
          title: 'Заполните профиль работодателя',
          description:
              'Реквизиты и доказательства нужны до работы с реальными документами.',
          completed: results[5],
          required: false,
          action: CompanySetupAction.compliance,
        ),
      ],
    );
  }
}
