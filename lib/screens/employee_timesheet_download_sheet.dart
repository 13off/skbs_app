import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

import '../app/app_adaptive_palette.dart';
import '../data/attendance_repository.dart';
import '../data/timesheet_excel_exporter.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import '../models/period_timesheet_row.dart';

class EmployeeTimesheetDownloadSheet {
  EmployeeTimesheetDownloadSheet._();

  static Future<void> show(
    BuildContext context, {
    required Employee employee,
    required DateTime initialDate,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmployeeTimesheetDownloadPanel(
        employee: employee,
        initialDate: initialDate,
      ),
    );
  }
}

enum _DownloadPeriodMode { months, dates }

class _EmployeeTimesheetDownloadPanel extends StatefulWidget {
  final Employee employee;
  final DateTime initialDate;

  const _EmployeeTimesheetDownloadPanel({
    required this.employee,
    required this.initialDate,
  });

  @override
  State<_EmployeeTimesheetDownloadPanel> createState() =>
      _EmployeeTimesheetDownloadPanelState();
}

class _EmployeeTimesheetDownloadPanelState
    extends State<_EmployeeTimesheetDownloadPanel> {
  late int shownYear;
  late Set<DateTime> selectedMonths;
  late DateTimeRange selectedRange;
  _DownloadPeriodMode mode = _DownloadPeriodMode.months;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    final initial = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      1,
    );
    shownYear = initial.year;
    selectedMonths = <DateTime>{initial};
    selectedRange = DateTimeRange(
      start: initial,
      end: DateTime(initial.year, initial.month + 1, 0),
    );
  }

  List<DateTime> get sortedMonths {
    final values = selectedMonths
        .map((month) => DateTime(month.year, month.month, 1))
        .toSet()
        .toList();
    values.sort((left, right) => left.compareTo(right));
    return values;
  }

  String get subtitle {
    final object = widget.employee.objectName.trim();
    return object.isEmpty
        ? widget.employee.name
        : '${widget.employee.name} · $object';
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Период табеля',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    setState(() => selectedRange = picked);
  }

  List<DateTime> monthsForRange(DateTimeRange range) {
    final result = <DateTime>[];
    var cursor = DateTime(range.start.year, range.start.month, 1);
    final last = DateTime(range.end.year, range.end.month, 1);
    while (!cursor.isAfter(last)) {
      result.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return result;
  }

  Future<void> export() async {
    if (isExporting) return;
    final months = mode == _DownloadPeriodMode.months
        ? sortedMonths
        : monthsForRange(selectedRange);
    if (months.isEmpty) return;

    setState(() => isExporting = true);
    try {
      if (mode == _DownloadPeriodMode.months) {
        await _exportMonths(months);
      } else {
        await _exportDateRange(months);
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Табель скачан')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось скачать табель: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> _exportMonths(List<DateTime> months) async {
    final rows = await Future.wait(
      months.map(
        (month) => AttendanceRepository.fetchMonthlyTimesheetForEmployee(
          employee: widget.employee,
          year: month.year,
          month: month.month,
        ),
      ),
    );

    await TimesheetExcelExporter.downloadMonthlyTimesheets(
      months: months,
      rowsByMonth: rows
          .map((row) => <MonthlyTimesheetRow>[row])
          .toList(growable: false),
      fileNamePrefix: 'Табель_${widget.employee.name}',
    );
  }

  Future<void> _exportDateRange(List<DateTime> months) async {
    final rows = await Future.wait(
      months.map(
        (month) => AttendanceRepository.fetchMonthlyTimesheetForEmployee(
          employee: widget.employee,
          year: month.year,
          month: month.month,
        ),
      ),
    );
    final rowsByMonth = <String, MonthlyTimesheetRow>{
      for (var index = 0; index < months.length; index++)
        _monthKey(months[index]): rows[index],
    };

    final shiftsByDate = <String, double>{};
    var date = selectedRange.start;
    while (!date.isAfter(selectedRange.end)) {
      final row = rowsByMonth[_monthKey(date)];
      shiftsByDate[AttendanceRepository.dateKey(date)] =
          row?.shiftForDay(date.day) ?? 0.0;
      date = date.add(const Duration(days: 1));
    }

    await _downloadExactPeriodWorkbook(
      PeriodTimesheetRow(employee: widget.employee, shiftsByDate: shiftsByDate),
    );
  }

  Future<void> _downloadExactPeriodWorkbook(PeriodTimesheetRow row) async {
    final workbook = Excel.createExcel();
    final sheet = workbook['Табель'];
    if (workbook.sheets.containsKey('Sheet1')) {
      workbook.delete('Sheet1');
    }

    sheet.appendRow(<CellValue?>[TextCellValue('Табель сотрудника')]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('Сотрудник'),
      TextCellValue(widget.employee.name),
    ]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('Должность'),
      TextCellValue(widget.employee.position),
    ]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('Объект'),
      TextCellValue(widget.employee.objectName),
    ]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('Период'),
      TextCellValue(
        '${_displayDate(selectedRange.start)} — ${_displayDate(selectedRange.end)}',
      ),
    ]);
    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('Дата'),
      TextCellValue('Статус'),
      TextCellValue('Смены'),
      TextCellValue('Ставка за смену'),
      TextCellValue('Начислено'),
      TextCellValue('Объект'),
    ]);

    var date = selectedRange.start;
    while (!date.isAfter(selectedRange.end)) {
      final shifts = row.shiftForDate(AttendanceRepository.dateKey(date));
      final accrued = shifts * widget.employee.dailyRate;
      sheet.appendRow(<CellValue?>[
        TextCellValue(_displayDate(date)),
        TextCellValue(shifts > 0 ? 'Работал' : 'Нет смены'),
        TextCellValue(_formatShift(shifts)),
        TextCellValue(_formatMoney(widget.employee.dailyRate)),
        TextCellValue(_formatMoney(accrued)),
        TextCellValue(widget.employee.objectName),
      ]);
      date = date.add(const Duration(days: 1));
    }

    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('ИТОГО'),
      TextCellValue(''),
      TextCellValue(_formatShift(row.totalShifts)),
      TextCellValue(''),
      TextCellValue(_formatMoney(row.accrued)),
      TextCellValue(''),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('Не удалось собрать Excel-файл');
    }

    final period =
        '${_dateKey(selectedRange.start)}_${_dateKey(selectedRange.end)}';
    final baseName = TimesheetExcelExporter.safeFileName(
      'Табель_${widget.employee.name}_$period',
    );
    final blob = html.Blob(<dynamic>[
      bytes,
    ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = '$baseName.xlsx'
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final selected = sortedMonths;
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceElevated,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppAdaptivePalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.textFaint,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Скачать табель',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: isExporting
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<_DownloadPeriodMode>(
                segments: const [
                  ButtonSegment<_DownloadPeriodMode>(
                    value: _DownloadPeriodMode.months,
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('Месяцы'),
                  ),
                  ButtonSegment<_DownloadPeriodMode>(
                    value: _DownloadPeriodMode.dates,
                    icon: Icon(Icons.date_range_outlined),
                    label: Text('Даты'),
                  ),
                ],
                selected: <_DownloadPeriodMode>{mode},
                onSelectionChanged: isExporting
                    ? null
                    : (value) => setState(() => mode = value.first),
              ),
              const SizedBox(height: 16),
              if (mode == _DownloadPeriodMode.months) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: isExporting
                            ? null
                            : () => setState(() => shownYear--),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '$shownYear',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: isExporting
                            ? null
                            : () => setState(() => shownYear++),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                  itemBuilder: (context, index) {
                    final month = DateTime(shownYear, index + 1, 1);
                    final isSelected = selected.any(
                      (item) =>
                          item.year == month.year && item.month == month.month,
                    );
                    return InkWell(
                      onTap: isExporting
                          ? null
                          : () {
                              setState(() {
                                if (isSelected) {
                                  selectedMonths.removeWhere(
                                    (item) =>
                                        item.year == month.year &&
                                        item.month == month.month,
                                  );
                                } else {
                                  selectedMonths.add(month);
                                }
                              });
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppAdaptivePalette.accentStrong
                              : AppAdaptivePalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppAdaptivePalette.accent
                                : AppAdaptivePalette.border,
                          ),
                        ),
                        child: Text(
                          TimesheetExcelExporter.monthName(index + 1),
                          style: TextStyle(
                            color: isSelected
                                ? AppAdaptivePalette.onAccent
                                : AppAdaptivePalette.textPrimary,
                            fontWeight: isSelected
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  selected.isEmpty
                      ? 'Месяцы не выбраны'
                      : 'Выбрано: ${selected.map(TimesheetExcelExporter.monthTitle).join(', ')}',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: isExporting ? null : pickDateRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    '${_displayDate(selectedRange.start)} — ${_displayDate(selectedRange.end)}',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'В Excel попадут только смены внутри выбранного диапазона.',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                      isExporting ||
                          (mode == _DownloadPeriodMode.months &&
                              selected.isEmpty)
                      ? null
                      : export,
                  icon: isExporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    isExporting ? 'Собираем Excel…' : 'Скачать Excel',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthKey(DateTime value) => '${value.year}-${value.month}';

  String _dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  String _displayDate(DateTime value) => DateFormat('dd.MM.yyyy').format(value);

  String _formatShift(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String _formatMoney(num value) {
    final text = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$text ₽';
  }
}
