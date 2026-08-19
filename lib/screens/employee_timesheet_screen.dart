import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/attendance_repository.dart';
import '../models/employee.dart';
import '../models/employee_timesheet_period_row.dart';
import '../models/monthly_timesheet_row.dart';
import '../widgets/adaptive_detail_body.dart';
import 'employee_timesheet_download_sheet.dart';

enum _EmployeeTimesheetPeriodMode { months, dates }

class EmployeeTimesheetScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeTimesheetScreen({super.key, required this.employee});

  @override
  State<EmployeeTimesheetScreen> createState() =>
      _EmployeeTimesheetScreenState();
}

class _EmployeeTimesheetScreenState extends State<EmployeeTimesheetScreen> {
  late Set<DateTime> selectedMonths;
  late DateTimeRange selectedRange;
  _EmployeeTimesheetPeriodMode mode = _EmployeeTimesheetPeriodMode.months;

  List<MonthlyTimesheetRow> monthlyRows = const <MonthlyTimesheetRow>[];
  EmployeeTimesheetPeriodRow? periodRow;
  bool isLoading = false;
  bool isExporting = false;
  String? errorText;
  int loadToken = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    selectedMonths = <DateTime>{month};
    selectedRange = DateTimeRange(
      start: month,
      end: DateTime(month.year, month.month + 1, 0),
    );
    loadReport();
  }

  List<DateTime> get sortedMonths {
    final values = selectedMonths
        .map((value) => DateTime(value.year, value.month, 1))
        .toSet()
        .toList();
    values.sort((left, right) => left.compareTo(right));
    return values;
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

  String monthShort(int month) {
    const names = <String>[
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    return names[month - 1];
  }

  String formatDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

  String formatShift(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatMoney(num value) {
    final text = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$text рублей';
  }

  String get selectionTitle {
    if (mode == _EmployeeTimesheetPeriodMode.dates) {
      return '${formatDate(selectedRange.start)} — ${formatDate(selectedRange.end)}';
    }
    final months = sortedMonths;
    if (months.isEmpty) return 'Месяцы не выбраны';
    if (months.length == 1) {
      final value = months.first;
      return '${monthName(value.month)} ${value.year}';
    }
    if (months.length <= 3) {
      return months
          .map((value) => '${monthShort(value.month)} ${value.year}')
          .join(', ');
    }
    return 'Выбрано месяцев: ${months.length}';
  }

  double get selectedShifts {
    if (mode == _EmployeeTimesheetPeriodMode.dates) {
      return periodRow?.totalShifts ?? 0;
    }
    return monthlyRows.fold<double>(
      0,
      (sum, item) => sum + item.totalShifts,
    );
  }

  double get selectedAccrued {
    if (mode == _EmployeeTimesheetPeriodMode.dates) {
      return periodRow?.accrued ?? 0;
    }
    return monthlyRows.fold<double>(0, (sum, item) => sum + item.accrued);
  }

  double get selectedPaid {
    if (mode == _EmployeeTimesheetPeriodMode.dates) {
      return periodRow?.paid ?? 0;
    }
    return monthlyRows.fold<double>(0, (sum, item) => sum + item.paid);
  }

  double get selectedBalance => selectedAccrued - selectedPaid;

  Future<void> loadReport() async {
    final currentToken = ++loadToken;
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      if (mode == _EmployeeTimesheetPeriodMode.months) {
        final months = sortedMonths;
        final loadedRows = await Future.wait(
          months.map(
            (month) => AttendanceRepository.fetchMonthlyTimesheetForEmployee(
              employee: widget.employee,
              year: month.year,
              month: month.month,
            ),
          ),
        );
        if (!mounted || currentToken != loadToken) return;
        setState(() {
          monthlyRows = loadedRows;
          periodRow = null;
          isLoading = false;
        });
      } else {
        final loadedRow =
            await AttendanceRepository.fetchTimesheetForEmployeePeriod(
              employee: widget.employee,
              startDate: selectedRange.start,
              endDate: selectedRange.end,
            );
        if (!mounted || currentToken != loadToken) return;
        setState(() {
          periodRow = loadedRow;
          monthlyRows = const <MonthlyTimesheetRow>[];
          isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted || currentToken != loadToken) return;
      setState(() {
        errorText = 'Ошибка загрузки табеля: $error';
        isLoading = false;
      });
    }
  }

  Future<void> setMode(_EmployeeTimesheetPeriodMode value) async {
    if (value == mode || isLoading) return;
    setState(() => mode = value);
    await loadReport();
  }

  Future<void> pickMonths() async {
    var shownYear = sortedMonths.isEmpty
        ? DateTime.now().year
        : sortedMonths.last.year;
    final draft = <DateTime>{...selectedMonths};
    final picked = await showModalBottomSheet<Set<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Выберите месяцы',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Можно выбрать несколько месяцев, в том числе не подряд.',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setSheetState(() => shownYear--),
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
                          onPressed: () => setSheetState(() => shownYear++),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.25,
                          ),
                      itemBuilder: (context, index) {
                        final month = DateTime(shownYear, index + 1, 1);
                        final selected = draft.contains(month);
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setSheetState(() {
                            if (selected) {
                              draft.remove(month);
                            } else {
                              draft.add(month);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppAdaptivePalette.accentStrong
                                  : AppAdaptivePalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? AppAdaptivePalette.accentStrong
                                    : AppAdaptivePalette.border,
                              ),
                            ),
                            child: Text(
                              monthName(month.month),
                              style: TextStyle(
                                color: selected
                                    ? AppAdaptivePalette.onAccent
                                    : AppAdaptivePalette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: draft.isEmpty
                                ? null
                                : () => Navigator.pop(
                                    sheetContext,
                                    Set<DateTime>.from(draft),
                                  ),
                            child: Text('Выбрать · ${draft.length}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() {
      selectedMonths = picked;
      mode = _EmployeeTimesheetPeriodMode.months;
    });
    await loadReport();
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedRange,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Период индивидуального табеля',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedRange = picked;
      mode = _EmployeeTimesheetPeriodMode.dates;
    });
    await loadReport();
  }

  Future<void> downloadExcel() async {
    if (isExporting) return;
    final initialDate = mode == _EmployeeTimesheetPeriodMode.dates
        ? selectedRange.start
        : sortedMonths.first;
    setState(() => isExporting = true);
    try {
      await EmployeeTimesheetDownloadSheet.show(
        context,
        employee: widget.employee,
        initialDate: initialDate,
      );
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  List<_TimesheetDayValue> selectedDays() {
    final result = <_TimesheetDayValue>[];
    if (mode == _EmployeeTimesheetPeriodMode.months) {
      final months = sortedMonths;
      for (var monthIndex = 0; monthIndex < months.length; monthIndex++) {
        final month = months[monthIndex];
        final row = monthIndex < monthlyRows.length
            ? monthlyRows[monthIndex]
            : null;
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        for (var day = 1; day <= daysInMonth; day++) {
          result.add(
            _TimesheetDayValue(
              date: DateTime(month.year, month.month, day),
              shifts: row?.shiftForDay(day) ?? 0,
            ),
          );
        }
      }
      return result;
    }

    var cursor = DateTime(
      selectedRange.start.year,
      selectedRange.start.month,
      selectedRange.start.day,
    );
    final end = DateTime(
      selectedRange.end.year,
      selectedRange.end.month,
      selectedRange.end.day,
    );
    while (!cursor.isAfter(end)) {
      result.add(
        _TimesheetDayValue(
          date: cursor,
          shifts:
              periodRow?.shiftForDate(AttendanceRepository.dateKey(cursor)) ??
              0,
        ),
      );
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  Widget buildSummary() {
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
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.employee.position} • ${widget.employee.objectName}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TimesheetSummaryChip(label: 'Выбрано', value: selectionTitle),
              _TimesheetSummaryChip(
                label: 'Смен',
                value: formatShift(selectedShifts),
              ),
              _TimesheetSummaryChip(
                label: 'Начислено',
                value: formatMoney(selectedAccrued),
              ),
              _TimesheetSummaryChip(
                label: 'Выплачено',
                value: formatMoney(selectedPaid),
              ),
              _TimesheetSummaryChip(
                label: 'Остаток за выбранное',
                value: formatMoney(selectedBalance),
                emphasize: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDaysList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorText != null) {
      return Text(
        errorText!,
        style: TextStyle(color: AppAdaptivePalette.danger),
      );
    }

    final values = selectedDays();
    if (values.isEmpty) {
      return Center(
        child: Text(
          'По выбранному периоду нет данных',
          style: TextStyle(color: AppAdaptivePalette.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 720
            ? 2
            : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: values.map((item) {
            final worked = item.shifts > 0;
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: worked
                      ? AppAdaptivePalette.success.withValues(alpha: 0.13)
                      : AppAdaptivePalette.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: worked
                        ? AppAdaptivePalette.success.withValues(alpha: 0.42)
                        : AppAdaptivePalette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      worked
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                      color: worked
                          ? AppAdaptivePalette.success
                          : AppAdaptivePalette.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        formatDate(item.date),
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatShift(item.shifts),
                      style: TextStyle(
                        color: worked
                            ? AppAdaptivePalette.success
                            : AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }

  Widget buildControls() {
    final canDownload = !isLoading && !isExporting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                selected: mode == _EmployeeTimesheetPeriodMode.months,
                onSelected: isLoading
                    ? null
                    : (_) => setMode(_EmployeeTimesheetPeriodMode.months),
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('Месяцы', textAlign: TextAlign.center),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                selected: mode == _EmployeeTimesheetPeriodMode.dates,
                onSelected: isLoading
                    ? null
                    : (_) => setMode(_EmployeeTimesheetPeriodMode.dates),
                label: const SizedBox(
                  width: double.infinity,
                  child: Text('Период', textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: isLoading || isExporting
                ? null
                : mode == _EmployeeTimesheetPeriodMode.months
                ? pickMonths
                : pickDateRange,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(selectionTitle, overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: canDownload ? downloadExcel : null,
            icon: isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            label: const Text('Скачать Excel'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Индивидуальный табель'),
      ),
      body: AdaptiveDetailBody(
        desktopMaxWidth: 1240,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildSummary(),
                    const SizedBox(height: 14),
                    buildControls(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: buildSummary()),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: buildControls()),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          buildDaysList(),
        ],
      ),
    );
  }
}

class _TimesheetDayValue {
  final DateTime date;
  final double shifts;

  const _TimesheetDayValue({required this.date, required this.shifts});
}

class _TimesheetSummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _TimesheetSummaryChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: emphasize
            ? AppAdaptivePalette.accentStrong.withValues(alpha: 0.12)
            : AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emphasize
              ? AppAdaptivePalette.accentStrong.withValues(alpha: 0.42)
              : AppAdaptivePalette.border,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: emphasize
                    ? AppAdaptivePalette.accentStrong
                    : AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
