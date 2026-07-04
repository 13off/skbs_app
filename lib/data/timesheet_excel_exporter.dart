import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../models/monthly_timesheet_row.dart';

class TimesheetExcelExporter {
  static const String _templatePath =
      'assets/templates/timesheet_template.xlsx';

  // Колонки шаблона:
  // A — месяц
  // B — ФИО
  // C — должность
  // D — объект
  // E — ставка
  // F:AJ — дни месяца
  // AK — итого смен
  // AL — начислено
  // AM — выплачено
  // AN — остаток
  // AO — комментарий
  static final List<String> _templateColumns = _generateColumns(41);

  static String monthName(int month) {
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

    return monthNames[month - 1];
  }

  static String monthTitle(DateTime month) {
    return '${monthName(month.month)} ${month.year}';
  }

  static String safeFileName(String value) {
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

  static String safeSheetName(String value) {
    final clean = value
        .replaceAll('[', '(')
        .replaceAll(']', ')')
        .replaceAll('*', '')
        .replaceAll('?', '')
        .replaceAll('/', '-')
        .replaceAll('\\', '-')
        .replaceAll(':', ' - ')
        .trim();

    if (clean.length <= 31) return clean;

    return clean.substring(0, 31).trim();
  }

  static String formatMoney(num value) {
    final text = value.toStringAsFixed(0);

    final withSpaces = text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ' ',
    );

    return '$withSpaces ₽';
  }

  static List<_MonthRows> _sortMonthRows({
    required List<DateTime> months,
    required List<List<MonthlyTimesheetRow>> rowsByMonth,
  }) {
    final result = <_MonthRows>[];

    for (var index = 0; index < months.length; index++) {
      result.add(
        _MonthRows(
          month: DateTime(months[index].year, months[index].month, 1),
          rows: rowsByMonth[index],
        ),
      );
    }

    result.sort((a, b) {
      final yearCompare = a.month.year.compareTo(b.month.year);
      if (yearCompare != 0) return yearCompare;
      return a.month.month.compareTo(b.month.month);
    });

    return result;
  }

  static double totalShifts(List<MonthlyTimesheetRow> rows) {
    return rows.fold<double>(0.0, (sum, row) => sum + row.totalShifts);
  }

  static double totalAccrued(List<MonthlyTimesheetRow> rows) {
    return rows.fold<double>(0.0, (sum, row) => sum + row.accrued);
  }

  static double totalPaid(List<MonthlyTimesheetRow> rows) {
    return rows.fold<double>(0.0, (sum, row) => sum + row.paid);
  }

  static double totalBalance(List<MonthlyTimesheetRow> rows) {
    return rows.fold<double>(0.0, (sum, row) => sum + row.balance);
  }

  static Future<void> downloadMonthlyTimesheets({
    required List<DateTime> months,
    required List<List<MonthlyTimesheetRow>> rowsByMonth,
    required String fileNamePrefix,
  }) async {
    if (months.isEmpty) {
      throw Exception('Не выбраны месяцы');
    }

    if (months.length != rowsByMonth.length) {
      throw Exception('Количество месяцев не совпадает с количеством табелей');
    }

    final monthRows = _sortMonthRows(months: months, rowsByMonth: rowsByMonth);

    final bytes = await _buildXlsxFromTemplate(monthRows);

    final firstMonth = monthRows.first.month;
    final lastMonth = monthRows.last.month;

    final filePeriod = monthRows.length == 1
        ? monthTitle(firstMonth)
        : '${monthTitle(firstMonth)}-${monthTitle(lastMonth)}';

    final fileName =
        '${safeFileName(fileNamePrefix)}_${safeFileName(filePeriod)}.xlsx';

    final blob = html.Blob([
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);

    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
  }

  static Future<Uint8List> _buildXlsxFromTemplate(
    List<_MonthRows> monthRows,
  ) async {
    final templateData = await rootBundle.load(_templatePath);
    final templateBytes = templateData.buffer.asUint8List(
      templateData.offsetInBytes,
      templateData.lengthInBytes,
    );

    final sourceArchive = ZipDecoder().decodeBytes(templateBytes);
    final files = <String, List<int>>{};

    String? templateSheetXml;

    for (final file in sourceArchive.files) {
      if (!file.isFile) continue;

      final name = file.name;
      final content = List<int>.from(file.content as List<int>);

      if (name == 'xl/worksheets/sheet1.xml') {
        templateSheetXml = utf8.decode(content);
      }

      if (_shouldDropTemplateFile(name)) {
        continue;
      }

      files[name] = content;
    }

    if (templateSheetXml == null) {
      throw Exception('В шаблоне не найден лист xl/worksheets/sheet1.xml');
    }

    for (var index = 0; index < monthRows.length; index++) {
      final item = monthRows[index];
      final sheetNumber = index + 1;

      final sheetXml = _fillSheetXml(
        templateXml: templateSheetXml,
        month: item.month,
        rows: item.rows,
      );

      files['xl/worksheets/sheet$sheetNumber.xml'] = utf8.encode(sheetXml);
    }

    final workbookXmlBytes = files['xl/workbook.xml'];
    if (workbookXmlBytes == null) {
      throw Exception('В шаблоне не найден xl/workbook.xml');
    }

    files['xl/workbook.xml'] = utf8.encode(
      _updateWorkbookXml(utf8.decode(workbookXmlBytes), monthRows),
    );

    final workbookRelsBytes = files['xl/_rels/workbook.xml.rels'];
    if (workbookRelsBytes == null) {
      throw Exception('В шаблоне не найден xl/_rels/workbook.xml.rels');
    }

    files['xl/_rels/workbook.xml.rels'] = utf8.encode(
      _updateWorkbookRelsXml(utf8.decode(workbookRelsBytes), monthRows.length),
    );

    final contentTypesBytes = files['[Content_Types].xml'];
    if (contentTypesBytes == null) {
      throw Exception('В шаблоне не найден [Content_Types].xml');
    }

    files['[Content_Types].xml'] = utf8.encode(
      _updateContentTypesXml(utf8.decode(contentTypesBytes), monthRows.length),
    );

    final resultArchive = Archive();

    for (final entry in files.entries) {
      resultArchive.addFile(
        ArchiveFile(entry.key, entry.value.length, entry.value),
      );
    }

    final resultBytes = ZipEncoder().encode(resultArchive);

    if (resultBytes == null) {
      throw Exception('Не удалось собрать Excel из шаблона');
    }

    return Uint8List.fromList(resultBytes);
  }

  static bool _shouldDropTemplateFile(String name) {
    if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(name)) {
      return true;
    }

    if (name.startsWith('xl/worksheets/_rels/')) {
      return true;
    }

    if (name == 'xl/calcChain.xml') {
      return true;
    }

    if (name.startsWith('xl/externalLinks/')) {
      return true;
    }

    if (name.startsWith('xl/tables/')) {
      return true;
    }

    return false;
  }

  static String _fillSheetXml({
    required String templateXml,
    required DateTime month,
    required List<MonthlyTimesheetRow> rows,
  }) {
    final editor = _SheetXmlEditor(templateXml, columns: _templateColumns);

    return editor.buildFilledSheet(month: month, rows: rows);
  }

  static String _updateWorkbookXml(
    String workbookXml,
    List<_MonthRows> monthRows,
  ) {
    var xml = workbookXml;

    xml = _removeXmlBlock(xml, 'definedNames');
    xml = _removeXmlBlock(xml, 'externalReferences');

    final prefix = _detectPrefix(xml, 'workbook');
    final sheetsTag = _tag(prefix, 'sheets');
    final sheetTag = _tag(prefix, 'sheet');

    final sheetsBuffer = StringBuffer();
    sheetsBuffer.write('<$sheetsTag>');

    for (var index = 0; index < monthRows.length; index++) {
      final sheetName = safeSheetName(monthTitle(monthRows[index].month));
      final sheetId = index + 1;

      sheetsBuffer.write(
        '<$sheetTag name="${_xmlAttr(sheetName)}" '
        'sheetId="$sheetId" '
        'r:id="rIdSheet$sheetId" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>',
      );
    }

    sheetsBuffer.write('</$sheetsTag>');

    final sheetsRegex = RegExp(
      '<$sheetsTag\\b[^>]*>.*?</$sheetsTag>',
      dotAll: true,
    );

    if (sheetsRegex.hasMatch(xml)) {
      return xml.replaceFirst(sheetsRegex, sheetsBuffer.toString());
    }

    final workbookTag = _tag(prefix, 'workbook');

    return xml.replaceFirst(
      '</$workbookTag>',
      '${sheetsBuffer.toString()}</$workbookTag>',
    );
  }

  static String _updateWorkbookRelsXml(String relsXml, int sheetCount) {
    var xml = relsXml;

    xml = xml.replaceAll(
      RegExp(
        r'<Relationship\b(?=[^>]*Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet")[^>]*/>',
      ),
      '',
    );

    xml = xml.replaceAll(
      RegExp(
        r'<Relationship\b(?=[^>]*Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/calcChain")[^>]*/>',
      ),
      '',
    );

    xml = xml.replaceAll(
      RegExp(
        r'<Relationship\b(?=[^>]*Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/externalLink")[^>]*/>',
      ),
      '',
    );

    final buffer = StringBuffer();

    for (var index = 1; index <= sheetCount; index++) {
      buffer.write(
        '<Relationship '
        'Id="rIdSheet$index" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet$index.xml"/>',
      );
    }

    return xml.replaceFirst(
      '</Relationships>',
      '${buffer.toString()}</Relationships>',
    );
  }

  static String _updateContentTypesXml(String contentTypesXml, int sheetCount) {
    var xml = contentTypesXml;

    xml = xml.replaceAll(
      RegExp(
        r'<Override\b(?=[^>]*PartName="/xl/worksheets/sheet\d+\.xml")[^>]*/>',
      ),
      '',
    );

    xml = xml.replaceAll(
      RegExp(r'<Override\b(?=[^>]*PartName="/xl/calcChain.xml")[^>]*/>'),
      '',
    );

    xml = xml.replaceAll(
      RegExp(r'<Override\b(?=[^>]*PartName="/xl/externalLinks/[^\"]+")[^>]*/>'),
      '',
    );

    xml = xml.replaceAll(
      RegExp(r'<Override\b(?=[^>]*PartName="/xl/tables/[^\"]+")[^>]*/>'),
      '',
    );

    final buffer = StringBuffer();

    for (var index = 1; index <= sheetCount; index++) {
      buffer.write(
        '<Override '
        'PartName="/xl/worksheets/sheet$index.xml" '
        'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
      );
    }

    return xml.replaceFirst('</Types>', '${buffer.toString()}</Types>');
  }

  static String _removeXmlBlock(String xml, String tagName) {
    return xml.replaceAll(
      RegExp(
        '<(?:[A-Za-z_][A-Za-z0-9_.-]*:)?$tagName\\b[^>]*>.*?</(?:[A-Za-z_][A-Za-z0-9_.-]*:)?$tagName>',
        dotAll: true,
      ),
      '',
    );
  }

  static String _detectPrefix(String xml, String tagName) {
    final match = RegExp(
      '<([A-Za-z_][A-Za-z0-9_.-]*):$tagName\\b',
    ).firstMatch(xml);

    return match?.group(1) ?? '';
  }

  static String _tag(String prefix, String tagName) {
    if (prefix.isEmpty) return tagName;
    return '$prefix:$tagName';
  }

  static String _xmlAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static List<String> _generateColumns(int count) {
    return List<String>.generate(count, (index) => _columnName(index + 1));
  }

  static String _columnName(int number) {
    var n = number;
    final chars = <String>[];

    while (n > 0) {
      n--;
      chars.insert(0, String.fromCharCode(65 + (n % 26)));
      n ~/= 26;
    }

    return chars.join();
  }
}

class _SheetXmlEditor {
  _SheetXmlEditor(this.originalXml, {required this.columns}) {
    prefix = TimesheetExcelExporter._detectPrefix(originalXml, 'worksheet');
    worksheetTag = TimesheetExcelExporter._tag(prefix, 'worksheet');
    dimensionTag = TimesheetExcelExporter._tag(prefix, 'dimension');
    sheetDataTag = TimesheetExcelExporter._tag(prefix, 'sheetData');
    rowTag = TimesheetExcelExporter._tag(prefix, 'row');
    cellTag = TimesheetExcelExporter._tag(prefix, 'c');
    valueTag = TimesheetExcelExporter._tag(prefix, 'v');
    inlineStringTag = TimesheetExcelExporter._tag(prefix, 'is');
    textTag = TimesheetExcelExporter._tag(prefix, 't');
  }

  final String originalXml;
  final List<String> columns;

  late final String prefix;
  late final String worksheetTag;
  late final String dimensionTag;
  late final String sheetDataTag;
  late final String rowTag;
  late final String cellTag;
  late final String valueTag;
  late final String inlineStringTag;
  late final String textTag;

  // Структура твоего Excel-шаблона:
  // 1 строка — заголовок/итоги месяца
  // 2 строка — пустая декоративная строка
  // 3 строка — шапка таблицы
  // 4 строка и ниже — сотрудники
  static const int _titleRow = 1;
  static const int _headerRow = 3;
  static const int _firstDataRow = 4;
  static const int _maxDaysInTemplate = 31;

  static const int _monthColumnIndex = 0;
  static const int _nameColumnIndex = 1;
  static const int _positionColumnIndex = 2;
  static const int _objectColumnIndex = 3;
  static const int _rateColumnIndex = 4;
  static const int _firstDayColumnIndex = 5;
  static const int _totalColumnIndex = 36;
  static const int _accruedColumnIndex = 37;
  static const int _paidColumnIndex = 38;
  static const int _balanceColumnIndex = 39;
  static const int _commentColumnIndex = 40;

  String buildFilledSheet({
    required DateTime month,
    required List<MonthlyTimesheetRow> rows,
  }) {
    var xml = _prepareWorksheetXml(originalXml);

    final sheetDataRegex = RegExp(
      '<$sheetDataTag\\b([^>]*)>(.*?)</$sheetDataTag>',
      dotAll: true,
    );

    final sheetDataMatch = sheetDataRegex.firstMatch(xml);

    if (sheetDataMatch == null) {
      throw Exception('В шаблоне не найден блок sheetData');
    }

    final sheetDataAttrs = sheetDataMatch.group(1) ?? '';
    final sheetDataBody = sheetDataMatch.group(2) ?? '';
    final templateRows = _extractRows(sheetDataBody);

    final maxExistingRow = templateRows.keys.isEmpty
        ? _headerRow
        : templateRows.keys.reduce(math.max);

    final totalRow = _firstDataRow + rows.length;
    final maxNeededRow = math.max(maxExistingRow, totalRow);

    final fallbackRow =
        templateRows[_firstDataRow] ??
        templateRows[_headerRow] ??
        '<$rowTag r="$_firstDataRow"></$rowTag>';

    final fallbackCellAttrs = _extractCellAttrs(fallbackRow);

    final newRows = <String>[];

    for (var rowNumber = 1; rowNumber <= maxNeededRow; rowNumber++) {
      final templateRow = templateRows[rowNumber] ?? fallbackRow;

      if (rowNumber == _titleRow) {
        newRows.add(
          _buildRow(
            templateRow: templateRow,
            rowNumber: rowNumber,
            values: _titleValues(month: month, rows: rows),
            fallbackCellAttrs: fallbackCellAttrs,
          ),
        );
        continue;
      }

      if (rowNumber == _headerRow) {
        newRows.add(
          _buildRow(
            templateRow: templateRow,
            rowNumber: rowNumber,
            values: _headerValues(month),
            fallbackCellAttrs: fallbackCellAttrs,
          ),
        );
        continue;
      }

      if (rowNumber >= _firstDataRow && rowNumber < totalRow) {
        final employeeIndex = rowNumber - _firstDataRow;

        newRows.add(
          _buildRow(
            templateRow: templateRow,
            rowNumber: rowNumber,
            values: _employeeValues(month: month, row: rows[employeeIndex]),
            fallbackCellAttrs: fallbackCellAttrs,
          ),
        );
        continue;
      }

      if (rowNumber == totalRow) {
        newRows.add(
          _buildRow(
            templateRow: templateRow,
            rowNumber: rowNumber,
            values: _totalValues(rows),
            fallbackCellAttrs: fallbackCellAttrs,
          ),
        );
        continue;
      }

      newRows.add(
        _buildRow(
          templateRow: templateRow,
          rowNumber: rowNumber,
          values: const {},
          fallbackCellAttrs: fallbackCellAttrs,
        ),
      );
    }

    final newSheetData =
        '<$sheetDataTag$sheetDataAttrs>${newRows.join()}</$sheetDataTag>';

    xml = xml.replaceFirst(sheetDataRegex, newSheetData);
    xml = _setDimension(xml, maxNeededRow);

    return xml;
  }

  String _prepareWorksheetXml(String xml) {
    var result = xml;

    // Убираем части, которые часто ломают экспорт при копировании листов:
    // таблицы, внешние проверки данных, внешние ссылки, r:id от настроек печати.
    result = TimesheetExcelExporter._removeXmlBlock(result, 'tableParts');
    result = TimesheetExcelExporter._removeXmlBlock(result, 'extLst');

    result = result.replaceAll(
      RegExp(
        '<(?:[A-Za-z_][A-Za-z0-9_.-]*:)?autoFilter\\b[^>]*/>',
        dotAll: true,
      ),
      '',
    );

    result = result.replaceAll(RegExp(r'\s+r:id="[^"]*"'), '');

    result = result.replaceAll(
      RegExp('<(?:[A-Za-z_][A-Za-z0-9_.-]*:)?dimension\\b[^>]*/>'),
      '',
    );

    return result;
  }

  String _setDimension(String xml, int maxRow) {
    final dimensionXml = '<$dimensionTag ref="A1:AO$maxRow"/>';

    return xml.replaceFirstMapped(
      RegExp('(<$worksheetTag\\b[^>]*>)'),
      (match) => '${match.group(1)}$dimensionXml',
    );
  }

  Map<int, String> _extractRows(String sheetDataBody) {
    final rows = <int, String>{};

    final rowRegex = RegExp('<$rowTag\\b([^>]*)>.*?</$rowTag>', dotAll: true);

    for (final match in rowRegex.allMatches(sheetDataBody)) {
      final rowXml = match.group(0)!;
      final attrs = match.group(1) ?? '';
      final rowNumberText = _attributeValue(attrs, 'r');
      final rowNumber = int.tryParse(rowNumberText ?? '');

      if (rowNumber == null) continue;

      rows[rowNumber] = rowXml;
    }

    return rows;
  }

  Map<String, String> _extractCellAttrs(String rowXml) {
    final result = <String, String>{};

    final cellRegex = RegExp(
      '<$cellTag\\b([^>]*?)(?:>.*?</$cellTag>|\\s*/>)',
      dotAll: true,
    );

    for (final match in cellRegex.allMatches(rowXml)) {
      final attrs = match.group(1) ?? '';
      final ref = _attributeValue(attrs, 'r');

      if (ref == null) continue;

      final column = _columnFromCellRef(ref);
      result[column] = _cleanCellAttrs(attrs);
    }

    return result;
  }

  String _buildRow({
    required String templateRow,
    required int rowNumber,
    required Map<String, _XlsxCell> values,
    required Map<String, String> fallbackCellAttrs,
  }) {
    final rowOpenMatch = RegExp(
      '<$rowTag\\b([^>]*)>',
      dotAll: true,
    ).firstMatch(templateRow);

    var rowAttrs = rowOpenMatch?.group(1) ?? '';
    rowAttrs = rowAttrs.replaceAll(RegExp(r'\s+r="[^"]*"'), '');
    rowAttrs = rowAttrs.replaceAll(RegExp(r'\s+spans="[^"]*"'), '');

    final rowCellAttrs = _extractCellAttrs(templateRow);

    final buffer = StringBuffer();
    buffer.write('<$rowTag r="$rowNumber" spans="1:41"$rowAttrs>');

    for (final column in columns) {
      final ref = '$column$rowNumber';
      final attrs = rowCellAttrs[column] ?? fallbackCellAttrs[column] ?? '';
      final value = values[column];

      buffer.write(_buildCell(ref: ref, attrs: attrs, value: value));
    }

    buffer.write('</$rowTag>');

    return buffer.toString();
  }

  String _buildCell({
    required String ref,
    required String attrs,
    required _XlsxCell? value,
  }) {
    if (value == null || value.isEmpty) {
      return '<$cellTag r="$ref"$attrs/>';
    }

    if (value.number != null) {
      return '<$cellTag r="$ref"$attrs><$valueTag>${_numberText(value.number!)}</$valueTag></$cellTag>';
    }

    final text = _xmlText(value.text ?? '');

    return '<$cellTag r="$ref"$attrs t="inlineStr">'
        '<$inlineStringTag>'
        '<$textTag xml:space="preserve">$text</$textTag>'
        '</$inlineStringTag>'
        '</$cellTag>';
  }

  Map<String, _XlsxCell> _titleValues({
    required DateTime month,
    required List<MonthlyTimesheetRow> rows,
  }) {
    final title = TimesheetExcelExporter.monthTitle(month);

    return {
      'B': _XlsxCell.text(
        'Табель: $title. '
        'Сотрудников: ${rows.length}. '
        'Начислено: ${TimesheetExcelExporter.formatMoney(TimesheetExcelExporter.totalAccrued(rows))}. '
        'Выплачено: ${TimesheetExcelExporter.formatMoney(TimesheetExcelExporter.totalPaid(rows))}. '
        'Остаток: ${TimesheetExcelExporter.formatMoney(TimesheetExcelExporter.totalBalance(rows))}.',
      ),
    };
  }

  Map<String, _XlsxCell> _headerValues(DateTime month) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final values = <String, _XlsxCell>{
      columns[_monthColumnIndex]: _XlsxCell.text('Месяц'),
      columns[_nameColumnIndex]: _XlsxCell.text('ФИО'),
      columns[_positionColumnIndex]: _XlsxCell.text('Должность'),
      columns[_objectColumnIndex]: _XlsxCell.text('Объект'),
      columns[_rateColumnIndex]: _XlsxCell.text('Ставка'),
      columns[_totalColumnIndex]: _XlsxCell.text('Итого смен'),
      columns[_accruedColumnIndex]: _XlsxCell.text('Начислено'),
      columns[_paidColumnIndex]: _XlsxCell.text('Выплачено'),
      columns[_balanceColumnIndex]: _XlsxCell.text('Остаток'),
      columns[_commentColumnIndex]: _XlsxCell.text('Комментарий'),
    };

    for (var day = 1; day <= _maxDaysInTemplate; day++) {
      final column = columns[_firstDayColumnIndex + day - 1];
      values[column] = day <= daysInMonth
          ? _XlsxCell.number(day)
          : const _XlsxCell.empty();
    }

    return values;
  }

  Map<String, _XlsxCell> _employeeValues({
    required DateTime month,
    required MonthlyTimesheetRow row,
  }) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final title = TimesheetExcelExporter.monthTitle(month);

    final values = <String, _XlsxCell>{
      columns[_monthColumnIndex]: _XlsxCell.text(title),
      columns[_nameColumnIndex]: _XlsxCell.text(row.employee.name),
      columns[_positionColumnIndex]: _XlsxCell.text(row.employee.position),
      columns[_objectColumnIndex]: _XlsxCell.text(row.employee.objectName),
      columns[_rateColumnIndex]: _XlsxCell.number(row.employee.dailyRate),
      columns[_totalColumnIndex]: _XlsxCell.number(row.totalShifts),
      columns[_accruedColumnIndex]: _XlsxCell.number(row.accrued),
      columns[_paidColumnIndex]: _XlsxCell.number(row.paid),
      columns[_balanceColumnIndex]: _XlsxCell.number(row.balance),
      columns[_commentColumnIndex]: const _XlsxCell.empty(),
    };

    for (var day = 1; day <= _maxDaysInTemplate; day++) {
      final column = columns[_firstDayColumnIndex + day - 1];
      values[column] = day <= daysInMonth
          ? _XlsxCell.number(row.shiftForDay(day))
          : const _XlsxCell.empty();
    }

    return values;
  }

  Map<String, _XlsxCell> _totalValues(List<MonthlyTimesheetRow> rows) {
    return {
      columns[_nameColumnIndex]: _XlsxCell.text('ИТОГО'),
      columns[_totalColumnIndex]: _XlsxCell.number(
        TimesheetExcelExporter.totalShifts(rows),
      ),
      columns[_accruedColumnIndex]: _XlsxCell.number(
        TimesheetExcelExporter.totalAccrued(rows),
      ),
      columns[_paidColumnIndex]: _XlsxCell.number(
        TimesheetExcelExporter.totalPaid(rows),
      ),
      columns[_balanceColumnIndex]: _XlsxCell.number(
        TimesheetExcelExporter.totalBalance(rows),
      ),
    };
  }

  String? _attributeValue(String attrs, String name) {
    final match = RegExp('(?:^|\\s)$name="([^"]*)"').firstMatch(attrs);
    return match?.group(1);
  }

  String _columnFromCellRef(String ref) {
    final match = RegExp(r'^[A-Z]+').firstMatch(ref);
    return match?.group(0) ?? ref;
  }

  String _cleanCellAttrs(String attrs) {
    var clean = attrs;

    clean = clean.replaceAll(RegExp(r'\s+r="[^"]*"'), '');
    clean = clean.replaceAll(RegExp(r'\s+t="[^"]*"'), '');
    clean = clean.replaceAll(RegExp(r'\s+cm="[^"]*"'), '');
    clean = clean.replaceAll(RegExp(r'\s+vm="[^"]*"'), '');

    return clean;
  }

  String _numberText(num value) {
    if (!value.isFinite) return '';

    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _xmlText(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}

class _XlsxCell {
  const _XlsxCell.empty() : text = null, number = null;

  const _XlsxCell.text(this.text) : number = null;

  const _XlsxCell.number(this.number) : text = null;

  final String? text;
  final num? number;

  bool get isEmpty => text == null && number == null;
}

class _MonthRows {
  const _MonthRows({required this.month, required this.rows});

  final DateTime month;
  final List<MonthlyTimesheetRow> rows;
}
