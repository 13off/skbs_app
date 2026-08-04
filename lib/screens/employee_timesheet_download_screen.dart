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
import '../widgets/adaptive_detail_body.dart';

enum _EmployeeTimesheetDownloadMode { months, dates }

class EmployeeTimesheetDownloadScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeTimesheetDownloadScreen({super.key, required this.employee});

  @override
  State<EmployeeTimesheetDownloadScreen> createState() =>
      _EmployeeTimesheetDownloadScreenState();
}

class _EmployeeTimesheetDownloadScreenState
    extends State<EmployeeTimesheetDownloadScreen> {
  _EmployeeTimesheetDownloadMode mode = _EmployeeTimesheetDownloadMode.months;
  late int visibleYear;
  late Set<DateTime> selectedMonths;
  late DateTimeRange selectedRange;
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    visibleYear = now.year;
    selectedMonths = <DateTime>{DateTime(now.year, now.month, 1)};
    selectedRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  DateTime cleanMonth(DateTime value) => DateTime(value.year, value.month, 1);

  bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  String monthKey(DateTime value) => '${value.year}-${value.month}';

  List<DateTime> get sortedMonths {
    final result = selectedMonths.map(cleanMonth).toSet().toList();
    result.sort((a, b) => a.compareTo(b));
    return result;
  }

  List<DateTime> monthsInRange(DateTime start, DateTime end) {
    final result = <DateTime>[];
    var month = DateTime(start.year, start.month, 1);
    final lastMonth = DateTime(end.year, end.month, 1);
    while (!month.isAfter(lastMonth)) {
      result.add(month);
      month = DateTime(month.year, month.month + 1, 1);
    }
    return result;
  }

  String monthName(int month) {
    const names = <String>[
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
    return names[month - 1];
  }

  String formatDate(DateTime value) => DateFormat('dd.MM.yyyy').format(value);

  String formatShift(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatMoney(num value) {
    final text = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$text ₽';
  }

  void toggleMonth(DateTime month) {
    final clean = cleanMonth(month);
    setState(() {
      final selected = selectedMonths.any((item) => isSameMonth(item, clean));
      if (selected) {
        selectedMonths.removeWhere((item) => isSameMonth(item, clean));
      } else {
        selectedMonths.add(clean);
      }
    });
  }

  void selectVisibleYear() {
    setState(() {
      for (var month = 1; month <= 12; month++) {
        selectedMonths.add(DateTime(visibleYear, month, 1));
      }
    });
  }

  void clearVisibleYear() {
    setState(() {
      selectedMonths.removeWhere((item) => item.year == visibleYear);
    });
  }

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDateRange: selectedRange,
      helpText: 'Период табеля',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
      fieldStartHintText: 'Начальная дата',
      fieldEndHintText: 'Конечная дата',
      fieldStartLabelText: 'С',
      fieldEndLabelText: 'По',
    );
    if (picked == null) return;
    setState(() {
      selectedRange = DateTimeRange(
        start: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  Future<void> download() async {
    if (isExporting) return;
    if (mode == _EmployeeTimesheetDownloadMode.months &&
        selectedMonths.isEmpty) {
      showMessage('Выберите хотя бы один месяц');
      return;
    }

    setState(() => isExporting = true);
    try {
      if (mode == _EmployeeTimesheetDownloadMode.months) {
        await downloadSelectedMonths();
      } else {
        await downloadDateRange();
      }
      if (!mounted) return;
      showMessage('Excel-файл создан');
    } catch (error) {
      if (!mounted) return;
      showMessage('Ошибка создания Excel: $error');
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Future<void> downloadSelectedMonths() async {
    final months = sortedMonths;
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
      rowsByMonth: rows.map((row) => <MonthlyTimesheetRow>[row]).toList(),
      fileNamePrefix: 'Табель_${widget.employee.name}',
    );
  }

  Future<void> downloadDateRange() async {
    final months = monthsInRange(selectedRange.start, selectedRange.end);
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
        monthKey(months[index]): rows[index],
    };

    final shiftsByDate = <String, double>{};
    var date = selectedRange.start;
    while (!date.isAfter(selectedRange.end)) {
      final monthRow = rowsByMonth[monthKey(date)];
      shiftsByDate[AttendanceRepository.dateKey(date)] =
          monthRow?.shiftForDay(date.day) ?? 0.0;
      date = date.add(const Duration(days: 1));
    }

    await downloadExactPeriodWorkbook(
      PeriodTimesheetRow(employee: widget.employee, shiftsByDate: shiftsByDate),
    );
  }

  Future<void> downloadExactPeriodWorkbook(PeriodTimesheetRow row) async {
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
        '${formatDate(selectedRange.start)} — ${formatDate(selectedRange.end)}',
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
        TextCellValue(formatDate(date)),
        TextCellValue(shifts > 0 ? 'Работал' : 'Нет смены'),
        TextCellValue(formatShift(shifts)),
        TextCellValue(formatMoney(widget.employee.dailyRate)),
        TextCellValue(formatMoney(accrued)),
        TextCellValue(widget.employee.objectName),
      ]);
      date = date.add(const Duration(days: 1));
    }

    sheet.appendRow(<CellValue?>[]);
    sheet.appendRow(<CellValue?>[
      TextCellValue('ИТОГО'),
      TextCellValue(''),
      TextCellValue(formatShift(row.totalShifts)),
      TextCellValue(''),
      TextCellValue(formatMoney(row.accrued)),
      TextCellValue(''),
    ]);

    final bytes = workbook.encode();
    if (bytes == null) {
      throw Exception('Не удалось собрать Excel-файл');
    }

    final period =
        '${formatDate(selectedRange.start)}-${formatDate(selectedRange.end)}';
    final baseName = TimesheetExcelExporter.safeFileName(
      'Табель_${widget.employee.name}_$period',
    );
    final fileName = '$baseName.xlsx';
    final blob = html.Blob(<dynamic>[
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

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget buildEmployeeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildModeSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<_EmployeeTimesheetDownloadMode>(
        segments: const <ButtonSegment<_EmployeeTimesheetDownloadMode>>[
          ButtonSegment<_EmployeeTimesheetDownloadMode>(
            value: _EmployeeTimesheetDownloadMode.months,
            icon: Icon(Icons.calendar_view_month_outlined),
            label: Text('По месяцам'),
          ),
          ButtonSegment<_EmployeeTimesheetDownloadMode>(
            value: _EmployeeTimesheetDownloadMode.dates,
            icon: Icon(Icons.date_range_outlined),
            label: Text('По датам'),
          ),
        ],
        selected: <_EmployeeTimesheetDownloadMode>{mode},
        onSelectionChanged: isExporting
            ? null
            : (values) => setState(() => mode = values.first),
      ),
    );
  }

  Widget buildMonthsPicker() {
    final selected = sortedMonths;
    return section(
      children: [
        const Text(
          'Выберите месяцы',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Можно выбрать месяцы из разных лет. Каждый месяц будет отдельным листом.',
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              onPressed: isExporting
                  ? null
                  : () => setState(() => visibleYear--),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  visibleYear.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: isExporting
                  ? null
                  : () => setState(() => visibleYear++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.25,
          ),
          itemBuilder: (context, index) {
            final month = DateTime(visibleYear, index + 1, 1);
            final isSelected = selectedMonths.any(
              (item) => isSameMonth(item, month),
            );
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isExporting ? null : () => toggleMonth(month),
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
                  monthName(index + 1),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected
                        ? AppAdaptivePalette.onAccent
                        : AppAdaptivePalette.textPrimary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isExporting ? null : selectVisibleYear,
              icon: const Icon(Icons.done_all),
              label: const Text('Выбрать год'),
            ),
            OutlinedButton.icon(
              onPressed: isExporting ? null : clearVisibleYear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Очистить год'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          selected.isEmpty
              ? 'Месяцы не выбраны'
              : 'Выбрано: ${selected.map((item) => '${monthName(item.month)} ${item.year}').join(', ')}',
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget buildDateRangePicker() {
    final days = selectedRange.duration.inDays + 1;
    return section(
      children: [
        const Text(
          'Точный период по датам',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'В файл попадут только даты внутри интервала, включая первый и последний день.',
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isExporting ? null : pickDateRange,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppAdaptivePalette.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppAdaptivePalette.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatDate(selectedRange.start)} — ${formatDate(selectedRange.end)}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$days ${daysWord(days)}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget section({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  String daysWord(int value) {
    final mod100 = value % 100;
    final mod10 = value % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }

  Widget buildDownloadButton() {
    final disabled =
        isExporting ||
        (mode == _EmployeeTimesheetDownloadMode.months &&
            selectedMonths.isEmpty);
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: disabled ? null : download,
        icon: isExporting
            ? const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        label: Text(isExporting ? 'Собираем Excel…' : 'Скачать Excel'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Скачать табель'),
      ),
      body: AdaptiveDetailBody(
        desktopMaxWidth: 940,
        children: [
          buildEmployeeCard(),
          const SizedBox(height: 16),
          buildModeSelector(),
          const SizedBox(height: 16),
          if (mode == _EmployeeTimesheetDownloadMode.months)
            buildMonthsPicker()
          else
            buildDateRangePicker(),
          const SizedBox(height: 16),
          buildDownloadButton(),
        ],
      ),
    );
  }
}
