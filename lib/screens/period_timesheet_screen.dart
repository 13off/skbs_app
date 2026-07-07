import 'package:flutter/material.dart';

import '../data/attendance_repository.dart';
import '../data/timesheet_excel_exporter.dart';
import '../models/monthly_timesheet_row.dart';
import 'add_payment_screen.dart';

class PeriodTimesheetScreen extends StatefulWidget {
  final String? selectedObjectName;

  const PeriodTimesheetScreen({super.key, required this.selectedObjectName});

  @override
  State<PeriodTimesheetScreen> createState() => _PeriodTimesheetScreenState();
}

class _PeriodTimesheetScreenState extends State<PeriodTimesheetScreen> {
  final searchController = TextEditingController();

  late DateTime selectedMonth;

  List<MonthlyTimesheetRow> rows = [];

  bool isLoading = false;
  bool isExporting = false;
  bool includeFiredEmployees = false;
  String? errorText;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);

    loadReport();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  int get daysInMonth {
    return DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
  }

  List<int> get days {
    return List.generate(daysInMonth, (index) => index + 1);
  }

  String monthName(int month) {
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

  String get monthTitle {
    return '${monthName(selectedMonth.month)} ${selectedMonth.year}';
  }

  String get objectTitle {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  String get fileObjectPart {
    return objectTitle
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll('\\', '_');
  }

  List<MonthlyTimesheetRow> buildFilteredRows() {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) return rows;

    return rows
        .where((row) {
          final name = row.employee.name.toLowerCase();
          final position = row.employee.position.toLowerCase();
          final objectName = row.employee.objectName.toLowerCase();

          return name.contains(query) ||
              position.contains(query) ||
              objectName.contains(query);
        })
        .toList(growable: false);
  }

  String formatShift(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatMoney(num value) {
    final text = value.round().toString();

    final formatted = text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$formatted ₽';
  }

  bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime cleanMonth(DateTime month) {
    return DateTime(month.year, month.month, 1);
  }

  List<DateTime> sortMonths(Iterable<DateTime> months) {
    final result = months.map(cleanMonth).toList();

    result.sort((a, b) {
      final yearCompare = a.year.compareTo(b.year);
      if (yearCompare != 0) return yearCompare;
      return a.month.compareTo(b.month);
    });

    return result;
  }

  bool isSameEmployee(MonthlyTimesheetRow a, MonthlyTimesheetRow b) {
    final aId = a.employee.id;
    final bId = b.employee.id;

    if (aId != null && bId != null) {
      return aId == bId;
    }

    return a.employee.name == b.employee.name;
  }

  Future<void> loadReport() async {
    final requestId = ++_loadRequestId;
    final month = selectedMonth;
    final selectedObjectName = widget.selectedObjectName;
    final includeFired = includeFiredEmployees;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await AttendanceRepository.fetchMonthlyTimesheet(
        year: month.year,
        month: month.month,
        objectName: selectedObjectName,
        includeFired: includeFired,
      );

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        rows = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        errorText = 'Ошибка загрузки табеля: $e';
        isLoading = false;
      });
    }
  }

  Future<void> pickMonth() async {
    int tempYear = selectedMonth.year;

    final pickedMonth = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
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
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                tempYear--;
                              });
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                tempYear.toString(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() {
                                tempYear++;
                              });
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
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

                        final isSelected =
                            selectedMonth.year == tempYear &&
                            selectedMonth.month == month;

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(
                              context,
                              DateTime(tempYear, month, 1),
                            );
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              monthName(month),
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final now = DateTime.now();

                          Navigator.pop(
                            context,
                            DateTime(now.year, now.month, 1),
                          );
                        },
                        icon: const Icon(Icons.today),
                        label: const Text('Текущий месяц'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedMonth == null) return;

    final cleanPickedMonth = cleanMonth(pickedMonth);

    if (isSameMonth(cleanPickedMonth, selectedMonth)) return;

    setState(() {
      selectedMonth = cleanPickedMonth;
    });

    await loadReport();
  }

  Future<List<DateTime>?> pickMonthsForDownload({
    required String title,
    String? subtitle,
  }) async {
    int tempYear = selectedMonth.year;
    final selectedMonths = <DateTime>{cleanMonth(selectedMonth)};

    return showModalBottomSheet<List<DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final picked = sortMonths(selectedMonths);

            return SafeArea(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
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
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setModalState(() {
                                  tempYear--;
                                });
                              },
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  tempYear.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setModalState(() {
                                  tempYear++;
                                });
                              },
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
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
                          final monthDate = DateTime(tempYear, month, 1);

                          final isSelected = selectedMonths.any((item) {
                            return isSameMonth(item, monthDate);
                          });

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedMonths.removeWhere((item) {
                                    return isSameMonth(item, monthDate);
                                  });
                                } else {
                                  selectedMonths.add(monthDate);
                                }
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isSelected) ...[
                                    Icon(
                                      Icons.check_circle,
                                      size: 18,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Flexible(
                                    child: Text(
                                      monthName(month),
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      Text(
                        picked.isEmpty
                            ? 'Месяцы не выбраны'
                            : 'Выбрано: ${picked.map((item) => '${monthName(item.month)} ${item.year}').join(', ')}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: picked.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(context, picked);
                                },
                          icon: const Icon(Icons.download),
                          label: const Text('Скачать Excel'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<List<MonthlyTimesheetRow>>> fetchRowsForMonths({
    required List<DateTime> months,
    MonthlyTimesheetRow? employeeRow,
  }) async {
    final rowsByMonth = <List<MonthlyTimesheetRow>>[];

    for (final month in months) {
      List<MonthlyTimesheetRow> monthRows;

      if (isSameMonth(month, selectedMonth) && errorText == null) {
        monthRows = rows;
      } else {
        monthRows = await AttendanceRepository.fetchMonthlyTimesheet(
          year: month.year,
          month: month.month,
          objectName: widget.selectedObjectName,
          includeFired: includeFiredEmployees,
        );
      }

      if (employeeRow == null) {
        rowsByMonth.add(monthRows);
      } else {
        rowsByMonth.add(
          monthRows
              .where((row) {
                return isSameEmployee(row, employeeRow);
              })
              .toList(growable: false),
        );
      }
    }

    return rowsByMonth;
  }

  Future<void> exportExcel({
    required List<DateTime> months,
    required String fileNamePrefix,
    MonthlyTimesheetRow? employeeRow,
  }) async {
    if (isExporting) return;

    setState(() {
      isExporting = true;
    });

    try {
      final rowsByMonth = await fetchRowsForMonths(
        months: months,
        employeeRow: employeeRow,
      );

      await TimesheetExcelExporter.downloadMonthlyTimesheets(
        months: months,
        rowsByMonth: rowsByMonth,
        fileNamePrefix: fileNamePrefix,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Excel-файл создан')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка создания Excel: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Future<void> downloadAllEmployeesExcel() async {
    final months = await pickMonthsForDownload(
      title: 'Скачать общий табель',
      subtitle: 'Выберите один или несколько месяцев',
    );

    if (!mounted || months == null || months.isEmpty) return;

    await exportExcel(
      months: months,
      fileNamePrefix: 'Табель_${fileObjectPart}_всех_сотрудников',
    );
  }

  Future<void> downloadEmployeeExcel(MonthlyTimesheetRow row) async {
    final months = await pickMonthsForDownload(
      title: 'Скачать табель сотрудника',
      subtitle: row.employee.name,
    );

    if (!mounted || months == null || months.isEmpty) return;

    await exportExcel(
      months: months,
      fileNamePrefix: 'Табель_${fileObjectPart}_${row.employee.name}',
      employeeRow: row,
    );
  }

  Future<void> openAddPaymentScreen() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: monthTitle,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    await loadReport();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Выплата сохранена, отчёт обновлён')),
    );
  }

  Future<void> toggleIncludeFired(bool value) async {
    if (includeFiredEmployees == value) return;

    setState(() {
      includeFiredEmployees = value;
    });

    await loadReport();
  }

  Widget buildFiredToggleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: includeFiredEmployees
            ? Theme.of(context).colorScheme.primaryContainer
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: includeFiredEmployees
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: includeFiredEmployees,
            onChanged: isLoading || isExporting
                ? null
                : (value) {
                    toggleIncludeFired(value ?? false);
                  },
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Учитывать уволенных',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryCard(List<MonthlyTimesheetRow> visibleRows) {
    var totalAccrued = 0.0;
    var totalPaid = 0.0;
    var totalBalance = 0.0;
    var activeRowsCount = 0;
    var firedRowsCount = 0;

    for (final row in visibleRows) {
      totalAccrued += row.accrued;
      totalPaid += row.paid;
      totalBalance += row.balance;

      if (row.employee.isActive) {
        activeRowsCount++;
      } else {
        firedRowsCount++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Итог по месяцу',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text('Месяц: $monthTitle'),
          Text('Объект: $objectTitle'),
          Text('Сотрудников: ${visibleRows.length}'),
          Text('Активных: $activeRowsCount'),
          if (includeFiredEmployees) Text('Уволенных: $firedRowsCount'),
          Text('Начислено: ${formatMoney(totalAccrued)}'),
          Text('Выплачено: ${formatMoney(totalPaid)}'),
          Text('Остаток: ${formatMoney(totalBalance)}'),
        ],
      ),
    );
  }

  List<DataColumn> buildColumns() {
    return [
      const DataColumn(label: Text('ФИО')),
      const DataColumn(label: Text('Должность')),
      const DataColumn(label: Text('Объект')),
      const DataColumn(label: Text('Ставка'), numeric: true),
      ...days.map((day) {
        return DataColumn(label: Text(day.toString()), numeric: true);
      }),
      const DataColumn(label: Text('Итого'), numeric: true),
      const DataColumn(label: Text('Начислено'), numeric: true),
      const DataColumn(label: Text('Выплачено'), numeric: true),
      const DataColumn(label: Text('Остаток'), numeric: true),
    ];
  }

  DataRow buildDataRow(MonthlyTimesheetRow row) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 250,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.employee.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 6),
                if (!row.employee.isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Уволен',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  onPressed: isLoading || isExporting
                      ? null
                      : () {
                          downloadEmployeeExcel(row);
                        },
                  icon: const Icon(Icons.download, size: 20),
                  tooltip: 'Скачать индивидуальный табель',
                ),
              ],
            ),
          ),
        ),
        DataCell(SizedBox(width: 130, child: Text(row.employee.position))),
        DataCell(SizedBox(width: 110, child: Text(row.employee.objectName))),
        DataCell(Text(formatMoney(row.employee.dailyRate))),
        ...days.map((day) {
          final shift = row.shiftForDay(day);

          return DataCell(
            Text(
              formatShift(shift),
              style: TextStyle(
                fontWeight: shift > 0 ? FontWeight.w800 : FontWeight.w400,
                color: shift > 0 ? Colors.black : Colors.grey,
              ),
            ),
          );
        }),
        DataCell(
          Text(
            formatShift(row.totalShifts),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.accrued),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.paid),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(
          Text(
            formatMoney(row.balance),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: row.balance > 0 ? Colors.red : Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTable(List<MonthlyTimesheetRow> visibleRows) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorText != null) {
      return Center(
        child: Text(errorText!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (visibleRows.isEmpty) {
      return const Center(child: Text('Нет сотрудников по этому поиску'));
    }

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: buildColumns(),
            rows: visibleRows.map((row) {
              return buildDataRow(row);
            }).toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = buildFilteredRows();

    final pageContent = <Widget>[
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Табель',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text('Месячный табель сотрудников'),
                Text(
                  'Объект: $objectTitle',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: isLoading || isExporting
                ? null
                : () {
                    openAddPaymentScreen();
                  },
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Выплата'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: isLoading || isExporting
                ? null
                : () {
                    downloadAllEmployeesExcel();
                  },
            icon: isExporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: const Text('Все'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: isLoading || isExporting ? null : pickMonth,
          icon: const Icon(Icons.calendar_month),
          label: Text('Месяц: $monthTitle'),
        ),
      ),
      const SizedBox(height: 10),
      buildFiredToggleCard(),
      const SizedBox(height: 10),
      TextField(
        controller: searchController,
        enabled: !isExporting,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          labelText: 'Поиск сотрудника',
          hintText: 'ФИО, должность или объект',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      const SizedBox(height: 14),
      buildSummaryCard(visibleRows),
      const SizedBox(height: 14),
      SizedBox(height: 460, child: buildTable(visibleRows)),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        children: pageContent,
      ),
    );
  }
}
