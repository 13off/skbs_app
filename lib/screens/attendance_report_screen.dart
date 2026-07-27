import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../models/attendance_report_row.dart';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late DateTime startDate;
  late DateTime endDate;

  bool isLoading = false;
  String? errorText;

  List<AttendanceReportRow> rows = [];

  @override
  void initState() {
    super.initState();

    final today = AppState.today;

    startDate = DateTime(today.year, today.month, 1);
    endDate = today;

    loadReport();
  }

  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }

  String formatMoney(double value) {
    final formatter = NumberFormat.decimalPattern('ru_RU');
    return '${formatter.format(value.round())} ₽';
  }

  double get totalShifts {
    return rows.fold(0, (sum, row) => sum + row.shifts);
  }

  double get totalAmount {
    return rows.fold(0, (sum, row) => sum + row.amount);
  }

  Future<void> loadReport() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final loadedRows = await AttendanceRepository.fetchReportForPeriod(
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      setState(() {
        rows = loadedRows;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки отчёта: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2024),
      lastDate: endDate,
      helpText: 'Дата начала периода',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      startDate = pickedDate;
    });

    await loadReport();
  }

  Future<void> pickEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime(2035),
      helpText: 'Дата конца периода',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      endDate = pickedDate;
    });

    await loadReport();
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
          const Text(
            'Итого за период',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text('Сотрудников: ${rows.length}'),
          Text('Смен: ${formatNumber(totalShifts)}'),
          Text('Сумма: ${formatMoney(totalAmount)}'),
        ],
      ),
    );
  }

  Widget buildReportRow(AttendanceReportRow row) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          row.employeeName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${row.position}\n'
          'Смен: ${formatNumber(row.shifts)} · '
          'Ставка: ${formatMoney(row.dailyRate.toDouble())}',
        ),
        trailing: Text(
          formatMoney(row.amount),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Отчёт по табелю'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : pickStartDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('С: ${formatDate(startDate)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : pickEndDate,
                  icon: const Icon(Icons.calendar_month),
                  label: Text('По: ${formatDate(endDate)}'),
                ),
              ),
            ],
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
              child: Text('За выбранный период выходов нет'),
            ),

          if (errorText == null) ...rows.map(buildReportRow),
        ],
      ),
    );
  }
}
