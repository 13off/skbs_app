import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/attendance_repository.dart';
import '../data/timesheet_excel_exporter.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';

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
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);

    loadReport();
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

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
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

  Future<void> loadReport() async {
    final currentToken = ++_loadToken;

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

      if (!mounted || currentToken != _loadToken) return;

      setState(() {
        row = loadedRow;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted || currentToken != _loadToken) return;

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
                    Row(
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
                            ),
                            child: Text(
                              monthName(month),
                              style: TextStyle(
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

    if (pickedMonth == null) return;

    if (pickedMonth.year == selectedMonth.year &&
        pickedMonth.month == selectedMonth.month) {
      return;
    }

    setState(() {
      selectedMonth = pickedMonth;
    });

    await loadReport();
  }

  Future<void> downloadExcel() async {
    final currentRow = row;

    if (currentRow == null) return;

    setState(() {
      isExporting = true;
    });

    try {
      await TimesheetExcelExporter.downloadMonthlyTimesheets(
        months: [selectedMonth],
        rowsByMonth: [
          [currentRow],
        ],
        fileNamePrefix: 'Табель_${widget.employee.name}',
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

  Widget buildSummary() {
    final currentRow = row;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.employee.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text('${widget.employee.position} • ${widget.employee.objectName}'),
          const SizedBox(height: 14),
          Text('Месяц: $monthTitle'),
          Text('Смен: ${formatShift(currentRow?.totalShifts ?? 0)}'),
          Text('Начислено: ${formatMoney(currentRow?.accrued ?? 0)}'),
          Text('Выплачено: ${formatMoney(currentRow?.paid ?? 0)}'),
          Text('Остаток: ${formatMoney(currentRow?.balance ?? 0)}'),
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
      return Text(errorText!, style: const TextStyle(color: Colors.red));
    }

    if (currentRow == null) {
      return const Center(child: Text('По этому сотруднику нет данных'));
    }

    return Column(
      children: days.map((day) {
        final shift = currentRow.shiftForDay(day);
        final date = DateTime(selectedMonth.year, selectedMonth.month, day);

        return Card(
          elevation: 0,
          color: shift > 0 ? Colors.green.shade50 : Colors.grey.shade100,
          child: ListTile(
            leading: Icon(
              shift > 0
                  ? Icons.check_circle_outline
                  : Icons.remove_circle_outline,
              color: shift > 0 ? Colors.green : Colors.grey,
            ),
            title: Text(formatDate(date)),
            trailing: Text(
              formatShift(shift),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: shift > 0 ? Colors.green.shade800 : Colors.grey,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canDownload = row != null && !isLoading && !isExporting;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Индивидуальный табель'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          buildSummary(),

          const SizedBox(height: 14),

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

          const SizedBox(height: 16),

          buildDaysList(),
        ],
      ),
    );
  }
}
