import 'package:flutter/material.dart';

import '../../../app/theme_controller.dart';
import '../../../data/object_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../milestones/data/milestone_repository.dart';
import '../../procurement/data/procurement_repository.dart';
import '../data/ai_action_audit_repository.dart';
import '../data/global_voice_context_controller.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

class GlobalVoiceManagementActionCoordinator {
  GlobalVoiceManagementActionCoordinator._();

  static const supportedTypes = <String>{
    'manage_object',
    'manage_milestone',
    'manage_supplier',
    'toggle_app_setting',
  };

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (action.type == 'toggle_app_setting') {
      return _applySetting(action);
    }
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
        'manage_object' => await _manageObject(profile, action),
        'manage_milestone' => await _manageMilestone(action),
        'manage_supplier' => await _manageSupplier(profile, action),
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
    if (action.type == 'manage_object' && !profile.isAdmin) {
      throw StateError('Управление объектами доступно только руководителю');
    }
    if (action.type == 'manage_milestone' &&
        !profile.isAdmin &&
        !profile.isForeman) {
      throw StateError('Управление целями недоступно текущей роли');
    }
    if (action.type == 'manage_supplier' &&
        !profile.isAdmin &&
        !profile.isProcurement) {
      throw StateError('Управление поставщиками недоступно текущей роли');
    }
  }

  static Future<AiActionExecutionResult> _applySetting(
    AiAssistantAction action,
  ) async {
    final controller = AppThemeController.instance;
    final setting = action.text('setting');
    if (setting == 'dark_theme') {
      final enabled = action.boolean('value');
      await controller.setDark(enabled);
      return AiActionExecutionResult(
        completed: true,
        message: enabled ? 'Тёмная тема включена' : 'Светлая тема включена',
        targetEntityType: 'app_setting',
        targetEntityId: 'dark_theme',
      );
    }
    if (setting == 'ui_scale') {
      final percent = action.number('value').round();
      if (!const <int>{80, 90, 100, 110, 120}.contains(percent)) {
        throw StateError('Недоступный масштаб интерфейса');
      }
      await controller.setUiScale(percent / 100);
      return AiActionExecutionResult(
        completed: true,
        message: 'Масштаб интерфейса: $percent%',
        targetEntityType: 'app_setting',
        targetEntityId: 'ui_scale',
      );
    }
    throw StateError('Неизвестная настройка интерфейса');
  }

  static Future<AiActionExecutionResult> _manageObject(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final operation = action.text('operation');
    switch (operation) {
      case 'create':
        final name = await ObjectRepository.addObject(name: action.text('new_name'));
        return AiActionExecutionResult(
          completed: true,
          message: 'Объект «$name» создан',
          targetEntityType: 'object',
          targetEntityId: name,
        );
      case 'rename':
        final oldName = action.text('old_name');
        final saved = await ObjectRepository.renameObject(
          oldName: oldName,
          newName: action.text('new_name'),
        );
        final selected = GlobalVoiceContextController.objectNameFor(
          profile.activeCompanyId,
        );
        if (selected == oldName) {
          GlobalVoiceContextController.setObjectName(
            companyId: profile.activeCompanyId,
            objectName: saved,
          );
        }
        return AiActionExecutionResult(
          completed: true,
          message: 'Объект переименован: $saved',
          targetEntityType: 'object',
          targetEntityId: saved,
        );
      case 'archive':
        final name = action.text('old_name');
        await ObjectRepository.archiveObject(name: name);
        if (GlobalVoiceContextController.objectNameFor(profile.activeCompanyId) ==
            name) {
          GlobalVoiceContextController.setObjectName(
            companyId: profile.activeCompanyId,
            objectName: null,
          );
        }
        return AiActionExecutionResult(
          completed: true,
          message: 'Объект «$name» архивирован',
          targetEntityType: 'object',
          targetEntityId: name,
        );
      case 'restore':
        final name = action.text('old_name');
        await ObjectRepository.restoreObject(name: name);
        return AiActionExecutionResult(
          completed: true,
          message: 'Объект «$name» восстановлен',
          targetEntityType: 'object',
          targetEntityId: name,
        );
      default:
        throw StateError('Неизвестная операция с объектом');
    }
  }

  static Future<AiActionExecutionResult> _manageMilestone(
    AiAssistantAction action,
  ) async {
    final operation = action.text('operation');
    if (operation == 'create') {
      final targetDate = action.date('target_date');
      if (targetDate == null) throw StateError('Не указан срок цели');
      final id = await MilestoneRepository.createMilestone(
        objectName: action.text('object_name'),
        title: action.text('title'),
        location: '',
        targetDate: targetDate,
        notes: '',
        checklist: const <MilestoneChecklistDraft>[],
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Цель «${action.text('title')}» создана',
        targetEntityType: 'milestone',
        targetEntityId: id,
      );
    }
    if (operation == 'status') {
      final id = action.text('milestone_id');
      await MilestoneRepository.updateMilestoneStatus(
        milestoneId: id,
        status: action.text('new_status'),
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Статус цели «${action.text('milestone_title')}» обновлён',
        targetEntityType: 'milestone',
        targetEntityId: id,
      );
    }
    throw StateError('Неизвестная операция с целью');
  }

  static Future<AiActionExecutionResult> _manageSupplier(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    final operation = action.text('operation');
    if (operation == 'create') {
      await ProcurementRepository.saveSupplier(
        companyId: profile.activeCompanyId,
        name: action.text('supplier_name'),
        inn: '',
        contactName: '',
        phone: '',
        email: '',
        comment: 'Создан голосовой командой',
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Поставщик «${action.text('supplier_name')}» добавлен',
        targetEntityType: 'procurement_supplier',
        targetEntityId: action.text('supplier_name'),
      );
    }
    if (operation == 'archive') {
      await ProcurementRepository.archiveSupplier(
        companyId: profile.activeCompanyId,
        supplierId: action.text('supplier_id'),
      );
      return AiActionExecutionResult(
        completed: true,
        message: 'Поставщик «${action.text('supplier_name')}» скрыт',
        targetEntityType: 'procurement_supplier',
        targetEntityId: action.text('supplier_id'),
      );
    }
    throw StateError('Неизвестная операция с поставщиком');
  }

  static Future<bool> _confirm(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final destructive =
        action.type == 'manage_object' && action.text('operation') == 'archive' ||
        action.type == 'manage_supplier' && action.text('operation') == 'archive';
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
                  Text(_summary(action), style: const TextStyle(height: 1.45, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: destructive ? scheme.errorContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      destructive
                          ? 'Данные не удаляются навсегда, но запись исчезнет из рабочего списка. Действие попадёт в журнал ИИ.'
                          : 'Изменение выполнится только после подтверждения и попадёт в журнал ИИ.',
                      style: TextStyle(
                        color: destructive ? scheme.onErrorContainer : scheme.onSurface,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
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
                          style: destructive
                              ? FilledButton.styleFrom(
                                  backgroundColor: scheme.error,
                                  foregroundColor: scheme.onError,
                                )
                              : null,
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
    if (action.type == 'manage_object') {
      return switch (action.text('operation')) {
        'create' => 'Создать объект «${action.text('new_name')}».',
        'rename' => 'Переименовать «${action.text('old_name')}» в «${action.text('new_name')}».',
        'archive' => 'Архивировать объект «${action.text('old_name')}».',
        'restore' => 'Восстановить объект «${action.text('old_name')}».',
        _ => action.title,
      };
    }
    if (action.type == 'manage_milestone') {
      return action.text('operation') == 'create'
          ? 'Создать цель «${action.text('title')}» на объекте ${action.text('object_name')} со сроком ${action.text('target_date')}.'
          : 'Изменить статус цели «${action.text('milestone_title')}»: ${action.text('old_status')} → ${action.text('new_status')}.';
    }
    if (action.type == 'manage_supplier') {
      return action.text('operation') == 'create'
          ? 'Добавить поставщика «${action.text('supplier_name')}».'
          : 'Скрыть поставщика «${action.text('supplier_name')}».';
    }
    return action.title;
  }
}
