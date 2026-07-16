import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

class PaymentReportEmployeeOption {
  final String key;
  final String name;
  final String position;
  final String objectTitle;
  final List<String> employeeIds;
  final List<String> objectNames;

  const PaymentReportEmployeeOption({
    required this.key,
    required this.name,
    required this.position,
    required this.objectTitle,
    required this.employeeIds,
    this.objectNames = const <String>[],
  });
}

class PaymentReportRequest {
  final DateTime? month;
  final String? employeeKey;
  final String? objectName;

  const PaymentReportRequest({
    required this.month,
    required this.employeeKey,
    this.objectName,
  });

  bool get isAllTime => month == null;
}

class PaymentReportExporter {
  static final _client = Supabase.instance.client;

  static Future<int> download({
    required PaymentReportRequest request,
    required List<PaymentReportEmployeeOption> employees,
  }) async {
    final objectName = request.objectName?.trim().toLowerCase();
    final objectEmployees = objectName == null || objectName.isEmpty
        ? employees
        : employees.where((employee) {
            return employee.objectNames.any(
              (value) => value.trim().toLowerCase() == objectName,
            );
          }).toList();
    final selectedEmployees = request.employeeKey == null
        ? objectEmployees
        : objectEmployees
              .where((employee) => employee.key == request.employeeKey)
              .toList();

    if (selectedEmployees.isEmpty) {
      throw Exception('Не выбран сотрудник для отчёта');
    }

    final employeeIds = selectedEmployees
        .expand((employee) => employee.employeeIds)
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (employeeIds.isEmpty) {
      throw Exception('У сотрудников нет ID для формирования отчёта');
    }

    final employeeById = <String, PaymentReportEmployeeOption>{};

    for (final employee in selectedEmployees) {
      for (final employeeId in employee.employeeIds) {
        final cleanId = employeeId.trim();

        if (cleanId.isNotEmpty) {
          employeeById[cleanId] = employee;
        }
      }
    }

    final paymentRows = await _fetchPaymentRows(
      employeeIds: employeeIds,
      month: request.month,
    );

    paymentRows.sort((first, second) {
      final firstDate = _parseDate(first['payment_date']);
      final secondDate = _parseDate(second['payment_date']);
      final dateCompare = secondDate.compareTo(firstDate);

      if (dateCompare != 0) return dateCompare;

      final firstName =
          employeeById[first['employee_id']?.toString()]?.name ?? '';
      final secondName =
          employeeById[second['employee_id']?.toString()]?.name ?? '';

      return firstName.compareTo(secondName);
    });

    final excel = Excel.createExcel();
    const sheetName = 'Выплаты';
    final sheet = excel[sheetName];

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    const headers = [
      'ФИО',
      'Должность',
      'Объект',
      'Период',
      'Дата выплаты',
      'Тип выплаты',
      'Сумма',
      'Комментарий',
    ];

    sheet.appendRow(headers.map(_text).toList());

    double total = 0;
    var exportedRows = 0;

    for (final row in paymentRows) {
      final employeeId = row['employee_id']?.toString() ?? '';
      final employee = employeeById[employeeId];

      if (employee == null) continue;

      final amount = _toDouble(row['amount']);
      final periodYear = _toInt(row['period_year']);
      final periodMonth = _toInt(row['period_month']);
      final paymentDate = _parseDate(row['payment_date']);

      sheet.appendRow([
        _text(employee.name),
        _text(employee.position),
        _text(employee.objectTitle),
        _text(_periodTitle(periodYear, periodMonth)),
        _text(_formatDate(paymentDate)),
        _text(_paymentTypeLabel(row['payment_type']?.toString() ?? '')),
        _text(_formatMoney(amount)),
        _text(row['comment']?.toString() ?? ''),
      ]);

      total += amount;
      exportedRows++;
    }

    sheet.appendRow([_text('')]);
    sheet.appendRow([
      _text('Итого'),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(_formatMoney(total)),
      _text(''),
    ]);

    for (var column = 0; column < headers.length; column++) {
      if (column == 0) {
        sheet.setColumnWidth(column, 32);
      } else if (column == 7) {
        sheet.setColumnWidth(column, 36);
      } else {
        sheet.setColumnWidth(column, 20);
      }
    }

    final bytes = excel.encode();

    if (bytes == null) {
      throw Exception('Не удалось сформировать отчёт');
    }

    _downloadBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: _fileName(
        request: request,
        selectedEmployees: selectedEmployees,
      ),
    );

    return exportedRows;
  }

  static Future<List<Map<String, dynamic>>> _fetchPaymentRows({
    required List<String> employeeIds,
    required DateTime? month,
  }) async {
    const fields =
        'employee_id, period_year, period_month, payment_date, amount, payment_type, comment';

    final result = <Map<String, dynamic>>[];

    for (var start = 0; start < employeeIds.length; start += 100) {
      final end = (start + 100) > employeeIds.length
          ? employeeIds.length
          : start + 100;
      final chunk = employeeIds.sublist(start, end);

      final List<dynamic> rows;

      if (month == null) {
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk);
      } else {
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk)
            .eq('period_year', month.year)
            .eq('period_month', month.month);
      }

      result.addAll(rows.map((row) => Map<String, dynamic>.from(row as Map)));
    }

    return result;
  }

  static TextCellValue _text(String value) {
    return TextCellValue(value.trim());
  }

  static DateTime _parseDate(dynamic value) {
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  static String _formatMoney(double value) {
    final rounded = value.round().toString();

    return rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
  }

  static String _periodTitle(int year, int month) {
    if (year <= 0 || month < 1 || month > 12) return '';

    return '${_monthName(month)} $year';
  }

  static String _monthName(int month) {
    const monthNames = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    if (month < 1 || month > monthNames.length) return 'Месяц';

    return monthNames[month - 1];
  }

  static String _paymentTypeLabel(String value) {
    switch (value) {
      case 'advance':
        return 'Аванс';
      case 'salary':
        return 'Заработная плата';
      case 'fine':
        return 'Штраф';
      default:
        return 'Другое';
    }
  }

  static String _fileName({
    required PaymentReportRequest request,
    required List<PaymentReportEmployeeOption> selectedEmployees,
  }) {
    final period = request.month == null
        ? 'за_все_время'
        : '${request.month!.year}_${request.month!.month.toString().padLeft(2, '0')}';
    final employee = selectedEmployees.length == 1
        ? '_${_safeFileName(selectedEmployees.first.name)}'
        : '';

    return 'Отчет_по_выплатам_$period$employee.xlsx';
  }

  static String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static void _downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    Future<void>.delayed(
      const Duration(seconds: 1),
      () => html.Url.revokeObjectUrl(url),
    );
  }
}
