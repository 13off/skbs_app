import 'package:flutter/material.dart';

import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../data/ai_action_audit_repository.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

/// Executes actions that exist only for the global microphone and delegates all
/// established actions to the existing AI coordinator.
class GlobalVoiceActionExecutionCoordinator {
  GlobalVoiceActionExecutionCoordinator._();

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (action.type != 'bulk_timesheet_update') {
      return AiActionExecutionCoordinator.execute(
        context: context,
        profile: profile,
        action: action,
      );
    }

    final audit = await AiActionAuditRepository.createProposed(
      companyId: profile.activeCompanyId,
      action: action,
    );
    try {
      final confirmed = await _confirmBulkTimesheet(context, action);
      if (!confirmed) {
        await AiActionAuditRepository.markCancelled(audit.id);
        return const AiActionExecutionResult.cancelled();
      }
      await AiActionAuditRepository.markConfirmed(audit.id);

      final result = await _applyBulkTimesheet(profile, action);
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

  static Future<AiActionExecutionResult> _applyBulkTimesheet(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    if (!profile.isAdmin && !profile.isForeman && !profile.isDeveloper) {
      throw StateError('У текущей роли нет права массово менять табель');
    }

    final objectName = action.text('object_name');
    final date = action.date('date');
    final defaultShifts = action.number('default_shifts').toDouble();
    if (objectName.isEmpty || date == null) {
      throw StateError('Для массового табеля нужны конкретный объект и дата');
    }
    if (!_validShift(defaultShifts)) {
      throw StateError('Некорректное значение смены');
    }

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName,
      includeFired: false,
      forceRefresh: true,
    );
    final activeEmployees = employees
        .where((employee) => employee.id?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (activeEmployees.isEmpty) {
      throw StateError('На объекте нет активных сотрудников для табеля');
    }

    final overrides = _overrideValues(action);
    final employeeIds = activeEmployees
        .map((employee) => employee.id!)
        .toSet();
    final unknownOverride = overrides.keys.where(
      (employeeId) => !employeeIds.contains(employeeId),
    );
    if (unknownOverride.isNotEmpty) {
      throw StateError('Состав сотрудников изменился. Повтори голосовую команду');
    }

    final original = await AttendanceRepository.fetchShiftValuesForDate(
      date,
      objectName: objectName,
      forceRefresh: true,
    );
    final values = <String, double>{};
    var changed = 0;
    for (final employee in activeEmployees) {
      final id = employee.id!;
      final next = overrides[id] ?? defaultShifts;
      if (!_validShift(next)) {
        throw StateError('Некорректное значение табеля для ${employee.name}');
      }
      values[id] = next;
      if ((original[id] ?? 0) != next) changed += 1;
    }

    await AttendanceRepository.saveTimesheet(
      date: date,
      employees: activeEmployees,
      shiftValuesByEmployeeId: values,
      originalShiftValuesByEmployeeId: original,
    );

    return AiActionExecutionResult(
      completed: true,
      message: changed == 0
          ? 'Табель уже содержал эти значения'
          : 'Табель обновлён: $changed сотрудников',
      targetEntityType: 'attendance_bulk',
      targetEntityId: '$objectName:${AttendanceRepository.dateKey(date)}',
    );
  }

  static bool _validShift(double value) {
    if (value < 0 || value > 3) return false;
    final tenths = value * 10;
    return (tenths - tenths.round()).abs() < 0.000001;
  }

  static Map<String, double> _overrideValues(AiAssistantAction action) {
    final raw = action.payload['overrides'];
    if (raw is! List) return const <String, double>{};
    final result = <String, double>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['employee_id']?.toString().trim() ?? '';
      final shifts = map['shifts'];
      final parsed = shifts is num
          ? shifts.toDouble()
          : double.tryParse(shifts?.toString().replaceAll(',', '.') ?? '');
      if (id.isNotEmpty && parsed != null) result[id] = parsed;
    }
    return result;
  }

  static List<String> _overrideLabels(AiAssistantAction action) {
    final raw = action.payload['overrides'];
    if (raw is! List) return const <String>[];
    return raw.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final name = map['employee_name']?.toString().trim() ?? '';
      final value = map['shifts']?.toString() ?? '';
      return name.isEmpty ? value : '$name → $value';
    }).where((value) => value.trim().isNotEmpty).toList(growable: false);
  }

  static Future<bool> _confirmBulkTimesheet(
    BuildContext context,
    AiAssistantAction action,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final overrides = _overrideLabels(action);
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Изменить табель массово?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  _ConfirmRow('Объект', action.text('object_name')),
                  _ConfirmRow('Дата', _date(action.text('date'))),
                  _ConfirmRow(
                    'Сотрудников',
                    '${action.number('affected_count').round()}',
                  ),
                  _ConfirmRow(
                    'Основное значение',
                    '${action.number('default_shifts')} смены',
                  ),
                  if (overrides.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Исключения',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    for (final value in overrides)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('• $value смены'),
                      ),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'После подтверждения AppСтрой одним сохранением обновит табель выбранного объекта. Действие попадёт в журнал ИИ.',
                      style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
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
                          child: const Text('Подтвердить и изменить'),
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

  static String _date(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return value;
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
