import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/attendance_repository.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import '../widgets/adaptive_detail_body.dart';
import 'employee_timesheet_download_screen.dart';

class EmployeeTimesheetScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeTimesheetScreen({super.key, required this.employee});

  @override
  State<EmployeeTimesheetScreen> createState() =>
      _EmployeeTimesheetScreenState();
}

class _EmployeeTimesheetScreenState extends State<EmployeeTimesheetScreen> {
  late DateTime selectedMonth;
  MonthlyTimesheetRow? row;

  bool isLoading = false;
  bool isExporting = false;
  String? errorText;
  int loadToken = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    loadReport();
  }

  int get daysInMonth =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;

  List<int> get days => List<int>.generate(daysInMonth, (index) => index + 1);

  String monthName(int month) {
    const monthNames = <String>[
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

  String get monthTitle =>
      '${monthName(selectedMonth.month)} ${selectedMonth.year}';

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
    return '$text ₽';
  }

  Future<void> loadReport() async {
    final currentToken = ++loadToken;
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final loadedRow =
          await AttendanceRepository.fetchMonthlyTimesheetForEmployee(
            employee: widget.employee,
            year: selectedMonth.year,
            month: selectedMonth.month,
          );
      if (!mounted || currentToken != loadToken) return;
      setState(() {
        row = loadedRow;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || currentToken != loadToken) return;
      setState(() {
        errorText = 'Ошибка загрузки табеля: $error';
        isLoading = false;
      });
    }
  }

  Future<void> pickMonth() async {
    var visibleYear = selectedMonth.year;
    final pickedMonth = await showModalBottomSheet<DateTime>(
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
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.textFaint,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Выберите месяц',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              setSheetState(() => visibleYear--),
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
                          onPressed: () =>
                              setSheetState(() => visibleYear++),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 2.4,
                          ),
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final isSelected = selectedMonth.year == visibleYear &&
                            selectedMonth.month == month;
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.pop(
                            sheetContext,
                            DateTime(visibleYear, month, 1),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppAdaptivePalette.accentStrong
                                  : AppAdaptivePalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              monthName(month),
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedMonth == null ||
        (pickedMonth.year == selectedMonth.year &&
            pickedMonth.month == selectedMonth.month)) {
      return;
    }
    setState(() => selectedMonth = pickedMonth);
    await loadReport();
  }

  Future<void> downloadExcel() async {
    if (isExporting) return;
    setState(() => isExporting = true);

    try {
      final size = MediaQuery.sizeOf(context);
      if (size.width < 720) {
        await showModalBottomSheet<void>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => FractionallySizedBox(
            heightFactor: 0.96,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: EmployeeTimesheetDownloadScreen(
                employee: widget.employee,
              ),
            ),
          ),
        );
      } else {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 940,
              height: size.height * 0.9,
              child: EmployeeTimesheetDownloadScreen(
                employee: widget.employee,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  Widget buildSummary() {
    final currentRow = row;
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
              _TimesheetSummaryChip(label: 'Месяц', value: monthTitle),
              _TimesheetSummaryChip(
                label: 'Смен',
                value: formatShift(currentRow?.totalShifts ?? 0),
              ),
              _TimesheetSummaryChip(
                label: 'Начислено',
                value: formatMoney(currentRow?.accrued ?? 0),
              ),
              _TimesheetSummaryChip(
                label: 'Выплачено',
                value: formatMoney(currentRow?.paid ?? 0),
              ),
              _TimesheetSummaryChip(
                label: 'Остаток',
                value: formatMoney(currentRow?.balance ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDaysList() {
    final currentRow = row;
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorText != null) {
      return Text(
        errorText!,
        style: TextStyle(color: AppAdaptivePalette.danger),
      );
    }
    if (currentRow == null) {
      return Center(
        child: Text(
          'По этому сотруднику нет данных',
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
        final width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: days.map((day) {
            final shift = currentRow.shiftForDay(day);
            final date = DateTime(selectedMonth.year, selectedMonth.month, day);
            final worked = shift > 0;
            return SizedBox(
              width: width,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                        formatDate(date),
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatShift(shift),
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
    final canDownload = row != null && !isLoading && !isExporting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: isLoading || isExporting ? null : pickMonth,
            icon: const Icon(Icons.calendar_month),
            label: Text(monthTitle),
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
                : const Icon(Icons.download),
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
                  SizedBox(width: 300, child: buildControls()),
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

class _TimesheetSummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _TimesheetSummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppAdaptivePalette.border),
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
                color: AppAdaptivePalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
