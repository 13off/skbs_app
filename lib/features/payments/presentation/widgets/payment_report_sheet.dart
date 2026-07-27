import 'package:flutter/material.dart';

import '../../../../app/app_adaptive_palette.dart';

import '../../../../widgets/object_employee_scope.dart';
import '../../data/payment_report_exporter.dart';

Color get _sheetCard => AppAdaptivePalette.surfaceElevated;
Color get _sheetSoft => AppAdaptivePalette.surfaceSoft;
Color get _sheetLine => AppAdaptivePalette.border;
Color get _sheetText => AppAdaptivePalette.textPrimary;
Color get _sheetMuted => AppAdaptivePalette.textMuted;

Future<PaymentReportRequest?> showPaymentReportSheet({
  required BuildContext context,
  required DateTime initialMonth,
  DateTimeRange? initialDateRange,
  required List<PaymentReportEmployeeOption> employees,
}) {
  return showModalBottomSheet<PaymentReportRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _PaymentReportSheet(
        initialMonth: initialMonth,
        initialDateRange: initialDateRange,
        employees: employees,
      );
    },
  );
}

class _PaymentReportSheet extends StatefulWidget {
  final DateTime initialMonth;
  final DateTimeRange? initialDateRange;
  final List<PaymentReportEmployeeOption> employees;

  const _PaymentReportSheet({
    required this.initialMonth,
    required this.initialDateRange,
    required this.employees,
  });

  @override
  State<_PaymentReportSheet> createState() => _PaymentReportSheetState();
}

class _PaymentReportSheetState extends State<_PaymentReportSheet> {
  static const _allEmployeesKey = '__all_employees__';

  late final List<DateTime> availableMonths;
  late String selectedPeriodKey;
  late DateTimeRange selectedDateRange;
  PaymentReportPeriodMode selectedPeriodMode =
      PaymentReportPeriodMode.settlementMonth;
  String? selectedObjectKey;
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
    selectedDateRange =
        widget.initialDateRange ??
        DateTimeRange(
          start: DateTime(initial.year, initial.month, 1),
          end: DateTime(initial.year, initial.month + 1, 0),
        );
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
    for (final month in availableMonths) {
      if (_monthKey(month) == selectedPeriodKey) return month;
    }

    return widget.initialMonth;
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: selectedDateRange,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Выберите даты фактических выплат',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    setState(() => selectedDateRange = picked);
  }

  List<String> get objectNames {
    final values =
        widget.employees
            .expand((employee) => employee.objectNames)
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<PaymentReportEmployeeOption> get filteredEmployees {
    final scope = selectedObjectKey;
    if (scope == null) return const <PaymentReportEmployeeOption>[];
    if (isAllObjectsScope(scope)) return widget.employees;
    final normalized = scope.trim().toLowerCase();
    return widget.employees.where((employee) {
      return employee.objectNames.any(
        (value) => value.trim().toLowerCase() == normalized,
      );
    }).toList();
  }

  void submit() {
    Navigator.pop(
      context,
      PaymentReportRequest(
        periodMode: selectedPeriodMode,
        month: selectedPeriodMode == PaymentReportPeriodMode.settlementMonth
            ? selectedMonth
            : null,
        paymentDateFrom:
            selectedPeriodMode == PaymentReportPeriodMode.paymentDateRange
            ? selectedDateRange.start
            : null,
        paymentDateTo:
            selectedPeriodMode == PaymentReportPeriodMode.paymentDateRange
            ? selectedDateRange.end
            : null,
        employeeKey: selectedEmployeeKey == _allEmployeesKey
            ? null
            : selectedEmployeeKey,
        objectName: isAllObjectsScope(selectedObjectKey)
            ? null
            : selectedObjectKey,
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
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
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
                      icon: Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Выбери объект, способ отбора периода и сотрудника.',
                  style: TextStyle(
                    color: _sheetMuted,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: 18),
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
                        initialValue: selectedObjectKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Объект',
                          hintText: 'Сначала выберите объект',
                          prefixIcon: Icon(Icons.apartment_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: allObjectsScopeValue,
                            child: Text('Все объекты'),
                          ),
                          ...objectNames.map((objectName) {
                            return DropdownMenuItem<String>(
                              value: objectName,
                              child: Text(objectName),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedObjectKey = value;
                            selectedEmployeeKey = _allEmployeesKey;
                          });
                        },
                      ),
                      SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Период отчёта',
                          style: TextStyle(
                            color: _sheetText,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Расчётный месяц'),
                            selected:
                                selectedPeriodMode ==
                                PaymentReportPeriodMode.settlementMonth,
                            onSelected: (_) {
                              setState(() {
                                selectedPeriodMode =
                                    PaymentReportPeriodMode.settlementMonth;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('По датам выплаты'),
                            selected:
                                selectedPeriodMode ==
                                PaymentReportPeriodMode.paymentDateRange,
                            onSelected: (_) {
                              setState(() {
                                selectedPeriodMode =
                                    PaymentReportPeriodMode.paymentDateRange;
                              });
                            },
                          ),
                          ChoiceChip(
                            label: const Text('За всё время'),
                            selected:
                                selectedPeriodMode ==
                                PaymentReportPeriodMode.allTime,
                            onSelected: (_) {
                              setState(() {
                                selectedPeriodMode =
                                    PaymentReportPeriodMode.allTime;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (selectedPeriodMode ==
                          PaymentReportPeriodMode.settlementMonth)
                        DropdownButtonFormField<String>(
                          initialValue: selectedPeriodKey,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Расчётный месяц',
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: availableMonths.map((month) {
                            return DropdownMenuItem<String>(
                              value: _monthKey(month),
                              child: Text(_monthTitle(month)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedPeriodKey = value);
                          },
                        )
                      else if (selectedPeriodMode ==
                          PaymentReportPeriodMode.paymentDateRange)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: pickDateRange,
                            icon: const Icon(Icons.date_range_outlined),
                            label: Text(
                              '${_formatDate(selectedDateRange.start)} — ${_formatDate(selectedDateRange.end)}',
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _sheetCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _sheetLine),
                          ),
                          child: Text(
                            'В отчёт войдут выплаты за всё время.',
                            style: TextStyle(
                              color: _sheetMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'payment-report-employee-${selectedObjectKey ?? 'none'}',
                        ),
                        initialValue: selectedEmployeeKey,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Сотрудник',
                          hintText: selectedObjectKey == null
                              ? 'Сначала выберите объект'
                              : 'Выберите сотрудника',
                          prefixIcon: Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _allEmployeesKey,
                            child: Text('Все сотрудники'),
                          ),
                          ...filteredEmployees.map((employee) {
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
                        onChanged: selectedObjectKey == null
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedEmployeeKey = value;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: selectedObjectKey == null ? null : submit,
                    icon: Icon(Icons.download_outlined),
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
