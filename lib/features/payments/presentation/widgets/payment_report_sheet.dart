import 'package:flutter/material.dart';

import '../../data/payment_report_exporter.dart';

const Color _sheetCard = Color(0xFFFFFFFF);
const Color _sheetSoft = Color(0xFFF2F3F5);
const Color _sheetLine = Color(0xFFE6E8EB);
const Color _sheetText = Color(0xFF1F2328);
const Color _sheetMuted = Color(0xFF6B7075);

Future<PaymentReportRequest?> showPaymentReportSheet({
  required BuildContext context,
  required DateTime initialMonth,
  required List<PaymentReportEmployeeOption> employees,
}) {
  return showModalBottomSheet<PaymentReportRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _PaymentReportSheet(
        initialMonth: initialMonth,
        employees: employees,
      );
    },
  );
}

class _PaymentReportSheet extends StatefulWidget {
  final DateTime initialMonth;
  final List<PaymentReportEmployeeOption> employees;

  const _PaymentReportSheet({
    required this.initialMonth,
    required this.employees,
  });

  @override
  State<_PaymentReportSheet> createState() => _PaymentReportSheetState();
}

class _PaymentReportSheetState extends State<_PaymentReportSheet> {
  static const _allTimeKey = '__all_time__';
  static const _allEmployeesKey = '__all_employees__';

  late final List<DateTime> availableMonths;
  late String selectedPeriodKey;
  String selectedEmployeeKey = _allEmployeesKey;

  @override
  void initState() {
    super.initState();

    final initial = DateTime(
      widget.initialMonth.year,
      widget.initialMonth.month,
      1,
    );

    availableMonths = List<DateTime>.generate(
      36,
      (index) => DateTime(initial.year, initial.month - index, 1),
    );

    selectedPeriodKey = _monthKey(initial);
  }

  String _monthKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  String _monthTitle(DateTime month) {
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

    return '${monthNames[month.month - 1]} ${month.year}';
  }

  DateTime? get selectedMonth {
    if (selectedPeriodKey == _allTimeKey) return null;

    for (final month in availableMonths) {
      if (_monthKey(month) == selectedPeriodKey) return month;
    }

    return widget.initialMonth;
  }

  void submit() {
    Navigator.pop(
      context,
      PaymentReportRequest(
        month: selectedMonth,
        employeeKey: selectedEmployeeKey == _allEmployeesKey
            ? null
            : selectedEmployeeKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _sheetCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _sheetLine),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4CCC2),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Отчёт по выплатам',
                        style: TextStyle(
                          color: _sheetText,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Выбери период и сотрудника. Таблица скачается одним XLSX-файлом.',
                  style: TextStyle(
                    color: _sheetMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _sheetSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _sheetLine),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedPeriodKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Период',
                          prefixIcon: Icon(Icons.calendar_month_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _allTimeKey,
                            child: Text('За всё время'),
                          ),
                          ...availableMonths.map((month) {
                            return DropdownMenuItem<String>(
                              value: _monthKey(month),
                              child: Text(_monthTitle(month)),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedPeriodKey = value;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployeeKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Сотрудник',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _allEmployeesKey,
                            child: Text('Все сотрудники'),
                          ),
                          ...widget.employees.map((employee) {
                            final subtitle = employee.objectTitle.trim();
                            final label = subtitle.isEmpty
                                ? employee.name
                                : '${employee.name} — $subtitle';

                            return DropdownMenuItem<String>(
                              value: employee.key,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedEmployeeKey = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: submit,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Скачать таблицу'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
