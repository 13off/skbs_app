import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../data/attendance_repository.dart';
import '../data/timesheet_excel_exporter.dart';
import '../models/monthly_timesheet_row.dart';
import 'period_timesheet/period_timesheet_report.dart';

class TimesheetDownloadSheet {
  TimesheetDownloadSheet._();

  static Future<void> show(
    BuildContext context, {
    required String? selectedObjectName,
    DateTime? initialDate,
    bool includeFired = false,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimesheetDownloadPanel(
        selectedObjectName: selectedObjectName,
        initialDate: initialDate ?? DateTime.now(),
        includeFired: includeFired,
      ),
    );
  }
}

enum _DownloadPeriodMode { months, dates }

class _TimesheetDownloadPanel extends StatefulWidget {
  final String? selectedObjectName;
  final DateTime initialDate;
  final bool includeFired;

  const _TimesheetDownloadPanel({
    required this.selectedObjectName,
    required this.initialDate,
    required this.includeFired,
  });

  @override
  State<_TimesheetDownloadPanel> createState() =>
      _TimesheetDownloadPanelState();
}

class _TimesheetDownloadPanelState extends State<_TimesheetDownloadPanel> {
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

  String get objectTitle {
    final value = widget.selectedObjectName?.trim() ?? '';
    return value.isEmpty ? 'Все объекты' : value;
  }

  String get fileObjectPart {
    return TimesheetExcelExporter.safeFileName(objectTitle);
  }

  List<DateTime> get sortedMonths {
    final values = selectedMonths
        .map((month) => DateTime(month.year, month.month, 1))
        .toSet()
        .toList();
    values.sort((left, right) => left.compareTo(right));
    return values;
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

  List<MonthlyTimesheetRow> filterRowsForRange(
    List<MonthlyTimesheetRow> rows,
    DateTime month,
    DateTimeRange range,
  ) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final fullMonth =
        !range.start.isAfter(monthStart) && !range.end.isBefore(monthEnd);

    return rows
        .map((row) {
          final shifts = <int, double>{};
          row.shiftsByDay.forEach((day, value) {
            final date = DateTime(month.year, month.month, day);
            if (!date.isBefore(range.start) && !date.isAfter(range.end)) {
              shifts[day] = value;
            }
          });
          return MonthlyTimesheetRow(
            employee: row.employee,
            shiftsByDay: shifts,
            paid: fullMonth ? row.paid : 0,
          );
        })
        .where((row) => row.totalShifts > 0)
        .toList(growable: false);
  }

  Future<List<MonthlyTimesheetRow>> fetchRows(DateTime month) async {
    final rows = await AttendanceRepository.fetchMonthlyTimesheet(
      year: month.year,
      month: month.month,
      objectName: widget.selectedObjectName,
      includeFired: widget.includeFired,
    );
    return PeriodTimesheetReport.collapseDuplicateRows(
      rows,
      collapseAcrossObjects: widget.selectedObjectName?.trim().isEmpty ?? true,
    ).where((row) => row.totalShifts > 0).toList(growable: false);
  }

  Future<void> export() async {
    if (isExporting) return;
    final months = mode == _DownloadPeriodMode.months
        ? sortedMonths
        : monthsForRange(selectedRange);
    if (months.isEmpty) return;

    setState(() => isExporting = true);
    try {
      final rowsByMonth = <List<MonthlyTimesheetRow>>[];
      for (final month in months) {
        var rows = await fetchRows(month);
        if (mode == _DownloadPeriodMode.dates) {
          rows = filterRowsForRange(rows, month, selectedRange);
        }
        rowsByMonth.add(rows);
      }

      await TimesheetExcelExporter.downloadMonthlyTimesheets(
        months: months,
        rowsByMonth: rowsByMonth,
        fileNamePrefix: mode == _DownloadPeriodMode.months
            ? 'Табель_${fileObjectPart}_всех_сотрудников'
            : 'Табель_${fileObjectPart}_${_dateKey(selectedRange.start)}_${_dateKey(selectedRange.end)}',
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Табель скачан')));
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
                          objectTitle,
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
                    isExporting ? 'Формируем Excel' : 'Скачать Excel',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _displayDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _dateKey(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
