import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../models/monthly_timesheet_row.dart';
import 'add_payment_screen.dart';

class MonthlyTimesheetScreen extends StatefulWidget {
  const MonthlyTimesheetScreen({super.key});

  @override
  State<MonthlyTimesheetScreen> createState() => _MonthlyTimesheetScreenState();
}

class _MonthlyTimesheetScreenState extends State<MonthlyTimesheetScreen> {
  late DateTime selectedMonth;

  bool isLoading = false;
  String? errorText;

  List<MonthlyTimesheetRow> rows = [];

  final monthNames = const [
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

  @override
  void initState() {
    super.initState();

    final today = AppState.today;
    selectedMonth = DateTime(today.year, today.month, 1);

    loadReport();
  }

  int get daysInMonth {
    return DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
  }

  String get monthTitle {
    return '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';
  }

  double get totalShifts {
    return rows.fold<double>(0.0, (sum, row) => sum + row.totalShifts);
  }

  double get totalAccrued {
    return rows.fold<double>(0.0, (sum, row) => sum + row.accrued);
  }

  double get totalPaid {
    return rows.fold<double>(0.0, (sum, row) => sum + row.paid);
  }

  double get totalBalance {
    return rows.fold<double>(0.0, (sum, row) => sum + row.balance);
  }

  String formatShift(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String formatMoney(num value) {
    final formatter = NumberFormat.decimalPattern('ru_RU');
    return '${formatter.format(value.round())} ₽';
  }

  Future<void> loadReport() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final loadedRows = await AttendanceRepository.fetchMonthlyTimesheet(
        year: selectedMonth.year,
        month: selectedMonth.month,
      );

      if (!mounted) return;

      setState(() {
        rows = loadedRows;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки табеля месяца: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> pickMonth() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите любой день нужного месяца',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;

    setState(() {
      selectedMonth = DateTime(pickedDate.year, pickedDate.month, 1);
    });

    await loadReport();
  }

  Future<void> openAddPaymentScreen() async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: monthTitle,
        ),
      ),
    );

    if (result == true) {
      await loadReport();
    }
  }

  Widget buildSummaryCard() {
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
          Text(
            monthTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text('Сотрудников: ${rows.length}'),
          Text('Итого смен: ${formatShift(totalShifts)}'),
          Text('Начислено: ${formatMoney(totalAccrued)}'),
          Text('Выплачено: ${formatMoney(totalPaid)}'),
          Text('Остаток: ${formatMoney(totalBalance)}'),
        ],
      ),
    );
  }

  List<DataColumn> buildColumns() {
    return [
      const DataColumn(label: Text('Месяц')),
      const DataColumn(label: Text('ФИО')),
      const DataColumn(label: Text('Ставка')),
      ...List.generate(daysInMonth, (index) {
        return DataColumn(label: Text((index + 1).toString()), numeric: true);
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
        DataCell(Text(monthNames[selectedMonth.month - 1])),
        DataCell(
          SizedBox(
            width: 220,
            child: Text(row.employee.name, overflow: TextOverflow.ellipsis),
          ),
        ),
        DataCell(Text(formatMoney(row.employee.dailyRate))),
        ...List.generate(daysInMonth, (index) {
          final day = index + 1;
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

  Widget buildTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(Colors.grey.shade200),
        columns: buildColumns(),
        rows: rows.map(buildDataRow).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Табель месяца'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            onPressed: isLoading ? null : pickMonth,
            icon: const Icon(Icons.calendar_month),
            label: Text('Месяц: $monthTitle'),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: isLoading ? null : openAddPaymentScreen,
              icon: const Icon(Icons.payments),
              label: const Text('Добавить выплату'),
            ),
          ),
          const SizedBox(height: 16),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),

          if (errorText != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          buildSummaryCard(),

          const SizedBox(height: 18),

          if (!isLoading && errorText == null && rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('За этот месяц данных нет'),
            ),

          if (errorText == null && rows.isNotEmpty) buildTable(),
        ],
      ),
    );
  }
}
