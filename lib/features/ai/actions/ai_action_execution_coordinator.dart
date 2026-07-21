import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/task_repository.dart';
import '../../../features/developer/data/developer_policy_repository.dart';
import '../../../features/tasks/task_edit_policy.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../screens/act_preview_screen.dart';
import '../../../screens/add_task_screen.dart';
import '../../../screens/edit_employee_screen.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import '../presentation/ai_action_confirmation_sheet.dart';
import '../presentation/ai_document_template_screen.dart';
import '../presentation/ai_employee_draft_screen.dart';
import '../presentation/ai_operational_audit_screen.dart';
import '../presentation/ai_operational_report_screen.dart';
import '../presentation/ai_payment_draft_screen.dart';
import '../presentation/ai_reminder_draft_screen.dart';

class AiActionExecutionResult {
  final bool completed;
  final String message;
  final String? targetEntityType;
  final String? targetEntityId;

  const AiActionExecutionResult({
    required this.completed,
    required this.message,
    this.targetEntityType,
    this.targetEntityId,
  });

  const AiActionExecutionResult.cancelled()
      : completed = false,
        message = 'Действие отменено',
        targetEntityType = null,
        targetEntityId = null;
}

class AiActionExecutionCoordinator {
  AiActionExecutionCoordinator._();

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    final audit = await AiActionAuditRepository.createProposed(
      companyId: profile.activeCompanyId,
      action: action,
    );

    try {
      if (action.type == 'prepare_timesheet_correction') {
        await _loadCurrentTimesheetValue(action);
      }

      if (!context.mounted) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }

      final confirmed = await AiActionConfirmationSheet.show(
        context,
        action: action,
      );
      if (!confirmed) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }

      await AiActionAuditRepository.markConfirmed(audit.id);
      if (!context.mounted) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }

      final result = switch (action.type) {
        'create_task_draft' => await _createTask(context, profile, action),
        'prepare_document' => await _prepareDocument(context, profile, action),
        'prepare_timesheet_correction' => await _correctTimesheet(action),
        'prepare_employee_update' =>
          await _prepareEmployeeUpdate(context, action),
        'create_employee_draft' => await _createEmployee(context, action),
        'prepare_payment' => await _preparePayment(context, action),
        'find_operational_anomalies' =>
          await _openOperationalAudit(context, action),
        'find_missing_receipts' || 'prepare_candidate_documents' =>
          await _openOperationalReport(context, profile, action),
        'open_period_timesheet' => await _openPeriodTimesheet(context, action),
        'prepare_work_act' => await _prepareWorkAct(context, action),
        'create_reminder' => await _createReminder(context, action),
        _ => throw UnsupportedError(
            'Действие «${action.type}» пока не поддерживается',
          ),
      };

      if (result.completed) {
        await AiActionAuditRepository.markCompleted(
          audit.id,
          targetEntityType: result.targetEntityType,
          targetEntityId: result.targetEntityId,
        );
      } else {
        await AiActionAuditRepository.markCancelled(audit.id);
      }
      return result;
    } catch (error) {
      await AiActionAuditRepository.markFailed(audit.id, error);
      rethrow;
    }
  }

  static Future<void> _loadCurrentTimesheetValue(
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    final date = action.date('date');
    if (employeeId.isEmpty || date == null) return;
    final objectName = action.text('object_name');
    final current = await AttendanceRepository.fetchShiftValuesForDate(
      date,
      objectName: objectName.isEmpty ? null : objectName,
      forceRefresh: true,
    );
    action.payload['current_shifts'] = current[employeeId] ?? 0.0;
  }

  static Future<AiActionExecutionResult> _createTask(
    BuildContext context,
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final objectName = action.text('object_name');
    final taskDate = action.date('date') ?? DateTime.now();
    if (objectName.isEmpty) {
      throw StateError('Для задачи нужно выбрать конкретный объект');
    }

    await DeveloperPolicyRepository.ensurePolicy(objectName);
    if (!TaskEditPolicy.canCreateForDate(
      profile,
      taskDate,
      objectName: objectName,
    )) {
      throw StateError('Для этой даты у текущей роли нет права создавать задачу');
    }
    if (!context.mounted) return const AiActionExecutionResult.cancelled();

    final draft = await Navigator.of(context).push<TaskCreateDraft>(
      CupertinoPageRoute<TaskCreateDraft>(
        builder: (_) => AddTaskScreen(
          initialDate: taskDate,
          objectName: objectName,
          initialAxes: action.text('axes'),
          initialWork: action.text('work'),
          initialAssigneeIds: action.stringList('assignee_ids'),
          initialRequireBeforePhoto: action.boolean('require_before_photo'),
          allowAnyDate:
              profile.isAdmin ||
              TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,
        ),
      ),
    );
    if (draft == null) return const AiActionExecutionResult.cancelled();

    final created = await TaskRepository.addTaskWithDetails(
      draft.task,
      objectName: objectName,
      assigneeIds: draft.assigneeIds,
      photos: draft.photos,
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Задача «${created.work}» создана',
      targetEntityType: 'task',
      targetEntityId: created.id,
    );
  }

  static Future<AiActionExecutionResult> _prepareDocument(
    BuildContext context,
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final completed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => AiDocumentTemplateScreen(
          profile: profile,
          action: action,
        ),
      ),
    );
    if (completed != true) return const AiActionExecutionResult.cancelled();
    return const AiActionExecutionResult(
      completed: true,
      message: 'Документ проверен и скачан',
      targetEntityType: 'document_download',
    );
  }

  static Future<AiActionExecutionResult> _createEmployee(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final employeeId = await Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => AiEmployeeDraftScreen(action: action),
      ),
    );
    if (employeeId == null || employeeId.isEmpty) {
      return const AiActionExecutionResult.cancelled();
    }
    return AiActionExecutionResult(
      completed: true,
      message: 'Сотрудник создан',
      targetEntityType: 'employee',
      targetEntityId: employeeId,
    );
  }

  static Future<AiActionExecutionResult> _preparePayment(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final paymentId = await Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => AiPaymentDraftScreen(action: action),
      ),
    );
    if (paymentId == null || paymentId.isEmpty) {
      return const AiActionExecutionResult.cancelled();
    }
    return AiActionExecutionResult(
      completed: true,
      message: 'Выплата сохранена',
      targetEntityType: 'payment',
      targetEntityId: paymentId,
    );
  }

  static Future<AiActionExecutionResult> _openOperationalAudit(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final completed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => AiOperationalAuditScreen(action: action),
      ),
    );
    if (completed != true) return const AiActionExecutionResult.cancelled();
    return AiActionExecutionResult(
      completed: true,
      message: 'Контрольный отчёт табеля и выплат проверен',
      targetEntityType: 'operational_audit',
      targetEntityId: action.text('month'),
    );
  }

  static Future<AiActionExecutionResult> _openOperationalReport(
    BuildContext context,
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final completed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => AiOperationalReportScreen(
          profile: profile,
          action: action,
        ),
      ),
    );
    if (completed != true) return const AiActionExecutionResult.cancelled();
    return AiActionExecutionResult(
      completed: true,
      message: action.type == 'find_missing_receipts'
          ? 'Список выплат без чеков проверен'
          : 'Пакет кандидата проверен',
      targetEntityType: action.type == 'find_missing_receipts'
          ? 'payment_receipt_report'
          : 'candidate_document_package',
      targetEntityId: action.text('application_id').isEmpty
          ? null
          : action.text('application_id'),
    );
  }

  static Future<AiActionExecutionResult> _openPeriodTimesheet(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final objectName = action.text('object_name');
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PeriodTimesheetScreen(
          selectedObjectName: objectName.isEmpty ? null : objectName,
        ),
      ),
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Месячный табель открыт для проверки',
      targetEntityType: 'period_timesheet',
      targetEntityId: action.text('month'),
    );
  }

  static Future<AiActionExecutionResult> _prepareWorkAct(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final date = action.date('date') ?? DateTime.now();
    final objectName = action.text('object_name');
    final tasks = await TaskRepository.fetchTasksForDate(
      date,
      objectName: objectName.isEmpty ? null : objectName,
      forceRefresh: true,
    );
    final completed = tasks
        .where((task) => task.status == 'Выполнено')
        .toList(growable: false);
    if (completed.isEmpty) {
      throw StateError('За выбранную дату нет выполненных задач для акта');
    }
    if (!context.mounted) return const AiActionExecutionResult.cancelled();
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => ActPreviewScreen(tasks: completed, date: date),
      ),
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Черновик акта открыт для проверки',
      targetEntityType: 'work_act',
      targetEntityId: _dateKey(date),
    );
  }

  static Future<AiActionExecutionResult> _correctTimesheet(
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    final objectName = action.text('object_name');
    final date = action.date('date');
    final newShifts = action.number('shifts').toDouble();
    final currentShifts = action.number('current_shifts').toDouble();
    if (employeeId.isEmpty || date == null) {
      throw StateError('Не хватает сотрудника или даты корректировки');
    }

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName.isEmpty ? null : objectName,
      includeFired: true,
      forceRefresh: true,
    );
    Employee? employee;
    for (final item in employees) {
      if (item.id == employeeId) {
        employee = item;
        break;
      }
    }
    if (employee == null) {
      throw StateError('Сотрудник для корректировки табеля не найден');
    }

    await AttendanceRepository.saveTimesheet(
      date: date,
      employees: <Employee>[employee],
      shiftValuesByEmployeeId: <String, double>{employeeId: newShifts},
      originalShiftValuesByEmployeeId: <String, double>{
        employeeId: currentShifts,
      },
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Табель сотрудника обновлён: $newShifts смены',
      targetEntityType: 'attendance',
      targetEntityId: '$employeeId:${_dateKey(date)}',
    );
  }

  static Future<AiActionExecutionResult> _prepareEmployeeUpdate(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    final objectName = action.text('object_name');
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName.isEmpty ? null : objectName,
      includeFired: true,
      forceRefresh: true,
    );
    Employee? employee;
    for (final item in employees) {
      if (item.id == employeeId) {
        employee = item;
        break;
      }
    }
    if (employee == null) throw StateError('Сотрудник не найден');
    if (!context.mounted) return const AiActionExecutionResult.cancelled();

    final proposedEmployee = Employee(
      employee.name,
      employee.position,
      employee.status,
      id: employee.id,
      phone: employee.phone,
      objectName: employee.objectName,
      dailyRate: action.number('daily_rate').round(),
      isActive: employee.isActive,
      comment: employee.comment,
    );
    final updated = await Navigator.of(context).push<Employee>(
      CupertinoPageRoute<Employee>(
        builder: (_) => EditEmployeeScreen(employee: proposedEmployee),
      ),
    );
    if (updated == null) return const AiActionExecutionResult.cancelled();
    return AiActionExecutionResult(
      completed: true,
      message: 'Карточка сотрудника обновлена',
      targetEntityType: 'employee',
      targetEntityId: updated.id,
    );
  }

  static Future<AiActionExecutionResult> _createReminder(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final reminderId = await Navigator.of(context).push<String>(
      CupertinoPageRoute<String>(
        builder: (_) => AiReminderDraftScreen(action: action),
      ),
    );
    if (reminderId == null || reminderId.isEmpty) {
      return const AiActionExecutionResult.cancelled();
    }
    return AiActionExecutionResult(
      completed: true,
      message: 'Напоминание создано',
      targetEntityType: 'developer_reminder',
      targetEntityId: reminderId,
    );
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
