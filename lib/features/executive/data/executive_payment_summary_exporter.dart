import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';

class ExecutiveExpressSummaryRow {
  final String employeeName;
  final String objectTitle;
  final String status;
  final double shifts;
  final double accrued;
  final double paid;
  final double systemBalance;
  final double amountToPay;
  final String transferPhone;
  final String bankName;
  final String recipientName;
  final String bankCard;

  const ExecutiveExpressSummaryRow({
    required this.employeeName,
    required this.objectTitle,
    required this.status,
    required this.shifts,
    required this.accrued,
    required this.paid,
    required this.systemBalance,
    required this.amountToPay,
    required this.transferPhone,
    required this.bankName,
    required this.recipientName,
    required this.bankCard,
  });
}

class ExecutivePaymentSummaryExporter {
  ExecutivePaymentSummaryExporter._();

  static String buildText({
    required String objectTitle,
    required String periodTitle,
    required String employeeFilterTitle,
    required List<ExecutiveExpressSummaryRow> rows,
  }) {
    final lines = <String>[
      'Экспресс-сводка',
      'Объект: $objectTitle',
      'Период: $periodTitle',
      'Сотрудники: $employeeFilterTitle',
      '',
    ];

    var total = 0.0;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      total += row.amountToPay > 0 ? row.amountToPay : 0;
      lines.add(
        '${index + 1}. ${_formatMoney(row.amountToPay)} — ${row.employeeName}',
      );
      if (objectTitle == 'Все объекты') {
        lines.add('   Объект: ${row.objectTitle}');
      }
      lines.add('   Статус: ${row.status}');
      lines.add(
        '   Остаток системы: ${_formatSignedMoney(row.systemBalance)}',
      );
      if (row.transferPhone.trim().isNotEmpty) {
        lines.add('   Телефон: ${row.transferPhone.trim()}');
      }
      if (row.bankName.trim().isNotEmpty) {
        lines.add('   Банк: ${row.bankName.trim()}');
      }
      if (row.recipientName.trim().isNotEmpty) {
        lines.add('   Получатель: ${row.recipientName.trim()}');
      }
      if (row.bankCard.trim().isNotEmpty) {
        lines.add('   Карта: ${row.bankCard.trim()}');
      }
      if (index != rows.length - 1) lines.add('');
    }

    lines
      ..add('')
      ..add('Итого к выплате: ${_formatMoney(total)}');

    return lines.join('\n');
  }

  static Future<void> saveText({
    required String objectTitle,
    required String periodTitle,
    required String employeeFilterTitle,
    required List<ExecutiveExpressSummaryRow> rows,
  }) async {
    final text = buildText(
      objectTitle: objectTitle,
      periodTitle: periodTitle,
      employeeFilterTitle: employeeFilterTitle,
      rows: rows,
    );
    await FileSaver.instance.saveFile(
      name: _fileName(
        prefix: 'Экспресс_сводка',
        objectTitle: objectTitle,
        periodTitle: periodTitle,
      ),
      bytes: Uint8List.fromList(utf8.encode(text)),
      fileExtension: 'txt',
      mimeType: MimeType.text,
    );
  }

  static Future<void> saveXlsx({
    required String objectTitle,
    required String periodTitle,
    required String employeeFilterTitle,
    required List<ExecutiveExpressSummaryRow> rows,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Сводка';
    final sheet = excel[sheetName];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    sheet.appendRow([
      _text('Экспресс-сводка'),
      _text('Объект: $objectTitle'),
      _text('Период: $periodTitle'),
      _text('Сотрудники: $employeeFilterTitle'),
    ]);
    sheet.appendRow([_text('')]);

    const headers = <String>[
      'ФИО',
      'Объект',
      'Статус',
      'Смены',
      'Начислено',
      'Выплачено',
      'Остаток системы',
      'К выплате',
      'Телефон для перевода',
      'Банк',
      'Получатель',
      'Карта',
    ];
    sheet.appendRow(headers.map(_text).toList());

    var total = 0.0;
    for (final row in rows) {
      total += row.amountToPay > 0 ? row.amountToPay : 0;
      sheet.appendRow([
        _text(row.employeeName),
        _text(row.objectTitle),
        _text(row.status),
        _text(_formatShifts(row.shifts)),
        _text(_formatMoney(row.accrued)),
        _text(_formatMoney(row.paid)),
        _text(_formatSignedMoney(row.systemBalance)),
        _text(_formatMoney(row.amountToPay)),
        _text(row.transferPhone),
        _text(row.bankName),
        _text(row.recipientName),
        _text(row.bankCard),
      ]);
    }

    sheet.appendRow([_text('')]);
    sheet.appendRow([
      _text('ИТОГО'),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(''),
      _text(_formatMoney(total)),
    ]);

    for (var column = 0; column < headers.length; column++) {
      if (column == 0) {
        sheet.setColumnWidth(column, 30);
      } else if (column == 8 || column == 10 || column == 11) {
        sheet.setColumnWidth(column, 24);
      } else {
        sheet.setColumnWidth(column, 18);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Не удалось сформировать XLSX');

    await FileSaver.instance.saveFile(
      name: _fileName(
        prefix: 'Экспресс_сводка',
        objectTitle: objectTitle,
        periodTitle: periodTitle,
      ),
      bytes: Uint8List.fromList(bytes),
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static TextCellValue _text(String value) => TextCellValue(value.trim());

  static String _formatMoney(num value) {
    final rounded = value > 0 ? value.round() : 0;
    return _groupDigits(rounded.toString());
  }

  static String _formatSignedMoney(num value) {
    final rounded = value.round();
    final sign = rounded < 0 ? '-' : '';
    return '$sign${_groupDigits(rounded.abs().toString())}';
  }

  static String _formatShifts(num value) {
    final number = value.toDouble();
    if (number == number.roundToDouble()) return number.round().toString();
    var text = number.toStringAsFixed(2);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);
    return text.replaceAll('.', ',');
  }

  static String _groupDigits(String value) {
    return value.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
  }

  static String _fileName({
    required String prefix,
    required String objectTitle,
    required String periodTitle,
  }) {
    final raw = '${prefix}_${objectTitle}_$periodTitle';
    return raw
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }
}
