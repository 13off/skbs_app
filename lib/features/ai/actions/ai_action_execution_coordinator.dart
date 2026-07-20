import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/task_repository.dart';
import '../../../features/developer/data/developer_policy_repository.dart';
import '../../../features/tasks/task_edit_policy.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../screens/add_task_screen.dart';
import '../../../screens/edit_employee_screen.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import '../presentation/ai_action_confirmation_sheet.dart';
import '../presentation/ai_document_draft_screen.dart';
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
    final current = await AttendanceRepository.fetchTimesheet(
      date: date,
      employeeIds: <String>[employeeId],
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
        builder: (_) => AiDocumentDraftScreen(
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

  static Future<AiActionExecutionResult> _correctTimesheet(
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    final date = action.date('date');
    final newShifts = action.number('shifts').toDouble();
    final currentShifts = action.number('current_shifts').toDouble();
    if (employeeId.isEmpty || date == null) {
      throw StateError('Не хватает сотрудника или даты корректировки');
    }

    await AttendanceRepository.saveTimesheet(
      date: date,
      originalValues: <String, double>{employeeId: currentShifts},
      newValues: <String, double>{employeeId: newShifts},
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
