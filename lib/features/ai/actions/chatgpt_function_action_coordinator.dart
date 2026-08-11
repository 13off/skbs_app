import 'package:flutter/material.dart';

import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/timesheet_excel_exporter.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/monthly_timesheet_row.dart';
import '../../payments/data/payment_report_exporter.dart';
import '../models/ai_assistant_result.dart';
import 'ai_action_execution_coordinator.dart';

/// Действия, которые появляются кнопкой прямо под ответом ChatGPT.
/// Кнопка сама считается подтверждением безопасной выгрузки; действия,
/// меняющие данные, по-прежнему проходят через существующие confirmation sheets.
class ChatGptFunctionActionCoordinator {
  ChatGptFunctionActionCoordinator._();

  static const supportedTypes = <String>{
    'download_timesheet_excel',
    'download_payment_report',
  };

  static Future<AiActionExecutionResult> execute({
    required BuildContext context,
    required AppUserProfile profile,
    required AiAssistantAction action,
  }) async {
    if (!supportedTypes.contains(action.type)) {
      throw UnsupportedError(action.type);
    }

    return switch (action.type) {
      'download_timesheet_excel' => _downloadTimesheet(profile, action),
      'download_payment_report' => _downloadPayments(profile, action),
      _ => throw UnsupportedError(action.type),
    };
  }

  static Future<AiActionExecutionResult> _downloadTimesheet(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    if (!profile.isAdmin &&
        !profile.isForeman &&
        !profile.isAccountant &&
        !profile.isDeveloper) {
      throw StateError('Выгрузка табеля недоступна текущей роли');
    }

    final month = _month(action.text('month')) ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final objectName = _objectName(action, profile);
    final rows = await AttendanceRepository.fetchMonthlyTimesheet(
      year: month.year,
      month: month.month,
      objectName: objectName,
      includeFired: true,
      forceRefresh: true,
    );

    final objectPart = (objectName ?? 'Все_объекты')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

    await TimesheetExcelExporter.downloadMonthlyTimesheets(
      months: <DateTime>[month],
      rowsByMonth: <List<MonthlyTimesheetRow>>[rows],
      fileNamePrefix: 'Табель_${objectPart}_всех_сотрудников',
    );

    return AiActionExecutionResult(
      completed: true,
      message: 'Табель за ${_monthTitle(month)} скачан',
      targetEntityType: 'timesheet_export',
      targetEntityId: '${month.year}-${month.month.toString().padLeft(2, '0')}',
    );
  }

  static Future<AiActionExecutionResult> _downloadPayments(
    AppUserProfile profile,
    AiAssistantAction action,
  ) async {
    if (!profile.isAdmin && !profile.isAccountant && !profile.isDeveloper) {
      throw StateError('Выгрузка выплат недоступна текущей роли');
    }

    final month = _month(action.text('month')) ??
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    final objectName = _objectName(action, profile);
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName,
      includeFired: true,
      forceRefresh: true,
    );

    final options = employees
        .where((employee) => employee.id?.trim().isNotEmpty == true)
        .map(
          (employee) => PaymentReportEmployeeOption(
            key: employee.id!,
            name: employee.name,
            position: employee.position,
            objectTitle: employee.objectName,
            employeeIds: <String>[employee.id!],
            objectNames: <String>[employee.objectName],
          ),
        )
        .toList(growable: false);

    if (options.isEmpty) {
      throw StateError('Нет сотрудников для формирования таблицы выплат');
    }

    final exportedRows = await PaymentReportExporter.download(
      request: PaymentReportRequest(
        month: month,
        employeeKey: null,
        objectName: objectName,
      ),
      employees: options,
    );

    return AiActionExecutionResult(
      completed: true,
      message: exportedRows == 0
          ? 'Таблица выплат за ${_monthTitle(month)} скачана; выплат за период нет'
          : 'Таблица выплат за ${_monthTitle(month)} скачана: $exportedRows строк',
      targetEntityType: 'payment_export',
      targetEntityId: '${month.year}-${month.month.toString().padLeft(2, '0')}',
    );
  }

  static String? _objectName(
    AiAssistantAction action,
    AppUserProfile profile,
  ) {
    final requested = action.text('object_name');
    if (requested.isNotEmpty &&
        requested.toLowerCase() != 'все доступные объекты' &&
        requested.toLowerCase() != 'все объекты') {
      return requested;
    }
    final assigned = profile.objectName.trim();
    return assigned.isEmpty ? null : assigned;
  }

  static DateTime? _month(String value) {
    final match = RegExp(r'^(20\d{2})-(0?[1-9]|1[0-2])$').firstMatch(value);
    if (match == null) return null;
    return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), 1);
  }

  static String _monthTitle(DateTime value) {
    const months = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }
}
