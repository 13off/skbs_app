import 'package:flutter/material.dart';

import '../../../data/employee_archive_repository.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../company_chat/data/company_chat_repository.dart';
import '../../employee/data/employee_shift_action_repository.dart';
import '../../employee/data/employee_shift_runtime.dart';
import '../../recruitment/data/recruitment_flight_repository.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

class GlobalVoiceWorkflowActionCoordinator {
  GlobalVoiceWorkflowActionCoordinator._();

  static const supportedTypes = <String>{
    'employee_workday',
    'employee_task_action',
    'manage_flight',
    'send_company_chat_message',
    'restore_archive_item',
  };

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    _checkRole(profile, action);
    final audit = await AiActionAuditRepository.createProposed(
      companyId: profile.activeCompanyId,
      action: action,
    );
    if (!context.mounted) {
      await AiActionAuditRepository.markCancelled(audit.id);
      return const AiActionExecutionResult.cancelled();
    }

    try {
      final confirmed = await _confirm(context, action);
      if (!confirmed) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }
      await AiActionAuditRepository.markConfirmed(audit.id);

      final result = switch (action.type) {
        'employee_workday' => await _workday(action),
        'employee_task_action' => await _taskAction(action),
        'manage_flight' => await _flight(profile, action),
        'send_company_chat_message' => await _sendChat(profile, action),
        'restore_archive_item' => await _restoreArchive(action),
        _ => throw UnsupportedError(action.type),
      };
      await AiActionAuditRepository.markCompleted(
        audit.id,
        targetEntityType: result.targetEntityType,
        targetEntityId: result.targetEntityId,
      );
      return result;
    } catch (error) {
      await AiActionAuditRepository.markFailed(audit.id, error);
      rethrow;
    }
  }

  static void _checkRole(AppUserProfile profile, AiAssistantAction action) {
    if ((action.type == 'employee_workday' ||
            action.type == 'employee_task_action') &&
        !profile.isEmployee) {
      throw StateError('Команда доступна только сотруднику');
    }
    if (action.type == 'manage_flight' && !profile.isAdmin && !profile.isHr) {
      throw StateError('Управление вылетами недоступно текущей роли');
    }
    if (action.type == 'send_company_chat_message' && profile.isEmployee) {
      throw StateError('Корпоративный чат недоступен текущей роли');
    }
    if (action.type == 'restore_archive_item' && !profile.isAdmin) {
      throw StateError('Восстановление из архива доступно руководителю');
    }
  }

  static Future<AiActionExecutionResult> _workday(
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    if (employeeId.isEmpty) throw StateError('Сотрудник не определён');
    final runtime = EmployeeShiftRuntime.instance;
    await runtime.bind(employeeId);
    if (action.text('operation') == 'start') {
      await runtime.start(employeeId);
      return AiActionExecutionResult(
        completed: true,
        message: 'Рабочий день начат',
        targetEntityType: 'employee_shift',
        targetEntityId: employeeId,
      );
    }
    if (action.text('operation') == 'finish') {
      await runtime.finish();
      return AiActionExecutionResult(
        completed: true,
        message: 'Рабочий день завершён',
        targetEntityType: 'employee_shift',
        targetEntityId: employeeId,
      );
    }
    throw StateError('Неизвестная команда рабочего дня');
  }

  static Future<AiActionExecutionResult> _taskAction(
    AiAssistantAction action,
  ) async {
    final employeeId = action.text('employee_id');
    final taskId = action.text('task_id');
    if (employeeId.isEmpty || taskId.isEmpty) {
      throw StateError('Не хватает сотрудника или задачи');
    }
    final operation = action.text('operation');
    if (operation == 'start_task') {
      await EmployeeShiftActionRepository.startTask(
        employeeId: employeeId,
        taskId: taskId,
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Выполнение задачи начато',
        targetEntityType: 'task',
        targetEntityId: taskId,
      );
    }
    if (operation == 'photo_before' || operation == 'photo_after') {
      final photos = await TaskRepository.pickPhotoFiles();
      if (photos.isEmpty) return const AiActionExecutionResult.cancelled();
      final stage = operation == 'photo_before' ? 'before' : 'after';
      await EmployeeShiftActionRepository.uploadTaskPhotos(
        employeeId: employeeId,
        taskId: taskId,
        stage: stage,
        photos: photos,
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Добавлено фотографий: ${photos.length}',
        targetEntityType: 'task_photo',
        targetEntityId: taskId,
      );
    }
    throw StateError('Неизвестное действие с задачей');
  }

  static Future<AiActionExecutionResult> _flight(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final data = await RecruitmentFlightRepository.fetchCalendar(
      companyId: profile.activeCompanyId,
    );
    final flightId = action.text('flight_id');
    final entry = data.flights.where((item) => item.flight.id == flightId).firstOrNull;
    if (entry == null) {
      throw StateError('Вылет изменился или больше недоступен. Повтори команду.');
    }
    if (action.text('operation') == 'remind') {
      await RecruitmentFlightRepository.sendReminder(entry);
      return AiActionExecutionResult(
        completed: true,
        message: 'Напоминание о вылете отправлено',
        targetEntityType: 'recruitment_flight',
        targetEntityId: flightId,
      );
    }
    if (action.text('operation') == 'status') {
      await RecruitmentFlightRepository.setStatus(
        flight: entry.flight,
        status: action.text('new_status'),
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Статус вылета обновлён',
        targetEntityType: 'recruitment_flight',
        targetEntityId: flightId,
      );
    }
    throw StateError('Неизвестная команда вылета');
  }

  static Future<AiActionExecutionResult> _sendChat(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final body = action.text('body');
    if (body.isEmpty) throw StateError('Текст сообщения пуст');
    final id = await CompanyChatRepository.createMessage(
      body: body,
      clientNonce:
          'voice-${profile.id}-${DateTime.now().microsecondsSinceEpoch}',
      channelKind: action.text('channel_kind'),
      peerUserId: action.text('peer_user_id').isEmpty
          ? null
          : action.text('peer_user_id'),
    );
    return AiActionExecutionResult(
      completed: true,
      message: 'Сообщение отправлено: ${action.text('peer_name')}',
      targetEntityType: 'company_chat_message',
      targetEntityId: id,
    );
  }

  static Future<AiActionExecutionResult> _restoreArchive(
    AiAssistantAction action,
  ) async {
    if (action.text('entity_type') != 'employee') {
      throw StateError('Этот тип архивной записи пока не поддерживается');
    }
    final employeeId = action.text('employee_id');
    await EmployeeArchiveRepository.restoreEmployee(employeeId);
    return AiActionExecutionResult(
      completed: true,
      message: '${action.text('employee_name')} восстановлен из архива',
      targetEntityType: 'employee',
      targetEntityId: employeeId,
    );
  }

  static Future<bool> _confirm(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final result = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Material(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    action.title,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _summary(action),
                    style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      action.type == 'employee_task_action' &&
                              action.text('operation').startsWith('photo_')
                          ? 'После подтверждения AppСтрой откроет штатный выбор фото. Сам файл голос не выбирает.'
                          : 'Действие выполнится только после подтверждения и попадёт в журнал ИИ.',
                      style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          child: const Text('Подтвердить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  static String _summary(AiAssistantAction action) {
    switch (action.type) {
      case 'employee_workday':
        return action.text('operation') == 'start'
            ? 'Начать рабочий день для ${action.text('employee_name')}.'
            : 'Завершить рабочий день для ${action.text('employee_name')}.';
      case 'employee_task_action':
        if (action.text('operation') == 'start_task') {
          return 'Начать выполнение задачи «${action.text('task_title')}».';
        }
        return 'Добавить ${action.text('photo_stage') == 'before' ? 'фото до' : 'фото после'} к задаче «${action.text('task_title')}».';
      case 'manage_flight':
        return action.text('operation') == 'remind'
            ? 'Отправить ${action.text('candidate_name')} напоминание о вылете.'
            : 'Изменить статус вылета ${action.text('candidate_name')}: ${action.text('current_status')} → ${action.text('new_status')}.';
      case 'send_company_chat_message':
        return '${action.text('peer_name')}: ${action.text('body')}';
      case 'restore_archive_item':
        return 'Восстановить ${action.text('employee_name')} из архива.';
      default:
        return action.title;
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
