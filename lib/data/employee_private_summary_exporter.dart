import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:universal_html/html.dart' as html;

import '../models/employee.dart';
import '../models/employee_private_data.dart';

class EmployeePrivateSummaryExporter {
  static Future<void> downloadSummary({
    required List<Employee> employees,
    required Map<String, EmployeePrivateData> privateDataByEmployeeId,
    String? objectName,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Сотрудники';
    final sheet = excel[sheetName];

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final headers = [
      'ФИО',
      'Должность',
      'Объект',
      'Статус',
      'Телефон',
      'Дата рождения',
      'Место рождения',
      'Паспорт',
      'Кем выдан',
      'Дата выдачи',
      'Код подразделения',
      'СНИЛС',
      'ИНН',
      'Адрес регистрации',
      'Адрес проживания',
      'Размер одежды',
      'Размер обуви',
      'Банк',
      'Карта',
      'Счёт',
      'Комментарий',
    ];

    sheet.appendRow(headers.map(_text).toList());

    for (final employee in employees) {
      final employeeId = employee.id ?? '';
      final data =
          privateDataByEmployeeId[employeeId] ??
          EmployeePrivateData.empty(employeeId);

      sheet.appendRow([
        _text(employee.name),
        _text(employee.position),
        _text(employee.objectName),
        _text(employee.isActive ? 'Активный' : 'Уволен'),
        _text(data.phone.trim().isEmpty ? employee.phone : data.phone),
        _text(data.birthDate),
        _text(data.birthPlace),
        _text(data.passportFull),
        _text(data.passportIssuedBy),
        _text(data.passportIssuedDate),
        _text(data.passportDepartmentCode),
        _text(data.snils),
        _text(data.inn),
        _text(data.registrationAddress),
        _text(data.livingAddress),
        _text(data.clothesSize),
        _text(data.shoeSize),
        _text(data.bankName),
        _text(data.bankCard),
        _text(data.bankAccount),
        _text(data.comment),
      ]);
    }

    for (var column = 0; column < headers.length; column++) {
      sheet.setColumnWidth(column, column < 5 ? 22 : 28);
    }

    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('Не удалось сформировать сводку');
    }

    final fileObject = objectName?.trim();
    final fileName = fileObject == null || fileObject.isEmpty
        ? 'Сводка_сотрудников.xlsx'
        : 'Сводка_сотрудников_${_safeFileName(fileObject)}.xlsx';

    _downloadBytes(bytes: Uint8List.fromList(bytes), fileName: fileName);
  }

  static TextCellValue _text(String value) {
    return TextCellValue(value.trim());
  }

  static String _safeFileName(String value) {
    return value
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(':', '_')
        .replaceAll('*', '_')
        .replaceAll('?', '_')
        .replaceAll('"', '_')
        .replaceAll('<', '_')
        .replaceAll('>', '_')
        .replaceAll('|', '_');
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

    html.Url.revokeObjectUrl(url);
  }
}
