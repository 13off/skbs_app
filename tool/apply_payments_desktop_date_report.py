from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"marker not found: {label}")
    return text.replace(old, new, 1)


payments_path = Path("lib/features/payments/presentation/screens/payments_screen.dart")
payments = payments_path.read_text(encoding="utf-8")

payments = replace_once(
    payments,
    "  List<_PaymentDisplayRow> rows = [];\n",
    "  List<_PaymentDisplayRow> rows = [];\n  List<Employee> reportEmployees = [];\n",
    "report employees state",
)

payments = replace_once(
    payments,
    """        rows = buildPaymentRows(
          mode == _PaymentAccountingMode.settlementPeriod
              ? periodRows
              : const <PeriodTimesheetRow>[],
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
""",
    """        rows = buildPaymentRows(
          mode == _PaymentAccountingMode.settlementPeriod
              ? periodRows
              : const <PeriodTimesheetRow>[],
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
        reportEmployees = scopedEmployees;
""",
    "store report employees",
)

payments = replace_once(
    payments,
    """  List<PaymentReportEmployeeOption> buildReportEmployeeOptions() {
    return rows.map((row) {
      return PaymentReportEmployeeOption(
        key: normalizedEmployeeKey(row.employee),
        name: row.employee.name,
        position: row.employee.position,
        objectTitle: row.objectTitle,
        employeeIds: List<String>.from(row.employeeIds),
        objectNames: List<String>.from(row.objectNames),
      );
    }).toList();
  }
""",
    """  List<PaymentReportEmployeeOption> buildReportEmployeeOptions() {
    if (reportEmployees.isEmpty) {
      return rows.map((row) {
        return PaymentReportEmployeeOption(
          key: normalizedEmployeeKey(row.employee),
          name: row.employee.name,
          position: row.employee.position,
          objectTitle: row.objectTitle,
          employeeIds: List<String>.from(row.employeeIds),
          objectNames: List<String>.from(row.objectNames),
        );
      }).toList();
    }

    final drafts = <String, _PaymentReportOptionDraft>{};
    for (final employee in reportEmployees) {
      final key = normalizedEmployeeKey(employee);
      drafts
          .putIfAbsent(key, () => _PaymentReportOptionDraft(employee))
          .add(employee);
    }

    final result = drafts.entries
        .map((entry) => entry.value.toOption(entry.key))
        .toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
""",
    "report options",
)

payments = replace_once(
    payments,
    """    final request = await showPaymentReportSheet(
      context: context,
      initialMonth: selectedMonth,
      employees: employeeOptions,
    );
""",
    """    final request = await showPaymentReportSheet(
      context: context,
      initialMonth: selectedMonth,
      initialDateRange:
          selectedRange ??
          DateTimeRange(
            start: DateTime(selectedMonth.year, selectedMonth.month, 1),
            end: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
          ),
      employees: employeeOptions,
    );
""",
    "report initial date range",
)

helpers = r'''  Widget buildDesktopSummaryPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accountingMode == _PaymentAccountingMode.settlementPeriod
                ? 'Сводка за расчётный период'
                : 'Движение денег за период',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          if (accountingMode == _PaymentAccountingMode.paymentDate)
            _MoneySummaryItem(
              title: 'Фактически выплачено',
              value: formatMoney(totalPaid),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Начислено',
                    value: formatMoney(totalAccrued),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Выплачено за период',
                    value: formatMoney(totalPaid),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MoneySummaryItem(
                    title: totalBalance >= 0 ? 'Остаток' : 'Переплата',
                    value: formatMoney(totalBalance.abs()),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<Widget> buildPaymentStatus(List<_PaymentDisplayRow> visibleRows) {
    return [
      if (isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(),
        ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            errorText!,
            style: TextStyle(color: AppAdaptivePalette.danger),
          ),
        ),
      if (!isLoading && visibleRows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: Text(
              'Сотрудники не найдены',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ];
  }

  Widget buildCompactPaymentsBody(List<_PaymentDisplayRow> visibleRows) {
    final leading = <Widget>[
      buildMonthPanel(),
      const SizedBox(height: 14),
      buildSummaryPanel(),
      const SizedBox(height: 14),
      buildSearch(),
      const SizedBox(height: 12),
      buildPaymentFilters(),
      const SizedBox(height: 16),
      ...buildPaymentStatus(visibleRows),
    ];
    final rowCount = isLoading && visibleRows.isEmpty ? 0 : visibleRows.length;

    return RefreshIndicator(
      onRefresh: () => loadPaymentsData(forceRefresh: true),
      child: ListView.builder(
        // Flutter 3.44 deprecates this field before exposing its replacement.
        // ignore: deprecated_member_use
        cacheExtent: 700,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
        itemCount: leading.length + rowCount,
        itemBuilder: (context, index) {
          final child = index < leading.length
              ? leading[index]
              : buildPaymentCard(visibleRows[index - leading.length]);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RepaintBoundary(child: child),
            ),
          );
        },
      ),
    );
  }

  Widget buildDesktopPaymentsBody(List<_PaymentDisplayRow> visibleRows) {
    return RefreshIndicator(
      onRefresh: () => loadPaymentsData(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 132),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: Column(
              children: [
                buildMonthPanel(),
                const SizedBox(height: 18),
                buildDesktopSummaryPanel(),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          buildSearch(),
                          const SizedBox(height: 14),
                          ...buildPaymentStatus(visibleRows),
                          if (!isLoading || visibleRows.isNotEmpty)
                            ...visibleRows.map(buildPaymentCard),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: [
                          buildPaymentFilters(),
                          const SizedBox(height: 14),
                          PremiumWorkCard(
                            radius: 22,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountingMode ==
                                          _PaymentAccountingMode.settlementPeriod
                                      ? 'Расчётный учёт'
                                      : 'Движение денег',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  accountingMode ==
                                          _PaymentAccountingMode.settlementPeriod
                                      ? 'Выплаты относятся к выбранному месяцу независимо от даты выдачи денег.'
                                      : 'Показываются только деньги, фактически выданные за выбранные даты.',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textMuted,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
'''
payments = replace_once(
    payments,
    "  @override\n  Widget build(BuildContext context) {\n",
    helpers,
    "desktop helpers",
)

payments = replace_once(
    payments,
    r'''  Widget build(BuildContext context) {
    final visibleRows = filteredRows;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        title: const Text('Выплаты'),
        actions: [buildReportAction(), buildAddAction()],
      ),
      body: PremiumWorkBackdrop(
        child: RefreshIndicator(
          onRefresh: () => loadPaymentsData(forceRefresh: true),
          child: Builder(
            builder: (context) {
              final leading = <Widget>[
                buildMonthPanel(),
                const SizedBox(height: 14),
                buildSummaryPanel(),
                const SizedBox(height: 14),
                buildSearch(),
                const SizedBox(height: 12),
                buildPaymentFilters(),
                const SizedBox(height: 16),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: LinearProgressIndicator(),
                  ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      errorText!,
                      style: TextStyle(color: AppAdaptivePalette.danger),
                    ),
                  ),
                if (!isLoading && visibleRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'Сотрудники не найдены',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ];
              final rowCount = isLoading && visibleRows.isEmpty
                  ? 0
                  : visibleRows.length;

              return ListView.builder(
                // Flutter 3.44 deprecates this field before exposing its replacement.
                // ignore: deprecated_member_use
                cacheExtent: 700,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                itemCount: leading.length + rowCount,
                itemBuilder: (context, index) {
                  final child = index < leading.length
                      ? leading[index]
                      : buildPaymentCard(visibleRows[index - leading.length]);
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: RepaintBoundary(child: child),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
''',
    r'''  Widget build(BuildContext context) {
    final visibleRows = filteredRows;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        title: const Text('Выплаты'),
        actions: [buildReportAction(), buildAddAction()],
      ),
      body: PremiumWorkBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1120;
            return desktop
                ? buildDesktopPaymentsBody(visibleRows)
                : buildCompactPaymentsBody(visibleRows);
          },
        ),
      ),
    );
  }
''',
    "responsive build",
)

payments = replace_once(
    payments,
    "class _MoneySummaryItem extends StatelessWidget {\n",
    r'''class _PaymentReportOptionDraft {
  final Employee firstEmployee;
  final Set<String> employeeIds = {};
  final Set<String> objectNames = {};

  _PaymentReportOptionDraft(this.firstEmployee);

  void add(Employee employee) {
    final employeeId = employee.id?.trim();
    final objectName = employee.objectName.trim();
    if (employeeId != null && employeeId.isNotEmpty) {
      employeeIds.add(employeeId);
    }
    if (objectName.isNotEmpty) {
      objectNames.add(objectName);
    }
  }

  PaymentReportEmployeeOption toOption(String key) {
    final objects = objectNames.toList()..sort();
    final objectTitle = objects.isEmpty
        ? 'Все объекты'
        : objects.length == 1
        ? objects.first
        : objects.join(', ');
    return PaymentReportEmployeeOption(
      key: key,
      name: firstEmployee.name,
      position: firstEmployee.position,
      objectTitle: objectTitle,
      employeeIds: employeeIds.toList(),
      objectNames: objects,
    );
  }
}

class _MoneySummaryItem extends StatelessWidget {
''',
    "report option draft",
)

payments_path.write_text(payments, encoding="utf-8")

sheet_path = Path("lib/features/payments/presentation/widgets/payment_report_sheet.dart")
sheet = sheet_path.read_text(encoding="utf-8")

sheet = replace_once(
    sheet,
    """  required DateTime initialMonth,
  required List<PaymentReportEmployeeOption> employees,
}) {
""",
    """  required DateTime initialMonth,
  DateTimeRange? initialDateRange,
  required List<PaymentReportEmployeeOption> employees,
}) {
""",
    "sheet signature",
)
sheet = replace_once(
    sheet,
    """        initialMonth: initialMonth,
        employees: employees,
""",
    """        initialMonth: initialMonth,
        initialDateRange: initialDateRange,
        employees: employees,
""",
    "sheet pass range",
)
sheet = replace_once(
    sheet,
    """  final DateTime initialMonth;
  final List<PaymentReportEmployeeOption> employees;

  const _PaymentReportSheet({
    required this.initialMonth,
    required this.employees,
  });
""",
    """  final DateTime initialMonth;
  final DateTimeRange? initialDateRange;
  final List<PaymentReportEmployeeOption> employees;

  const _PaymentReportSheet({
    required this.initialMonth,
    required this.initialDateRange,
    required this.employees,
  });
""",
    "sheet widget range",
)
sheet = replace_once(sheet, "  static const _allTimeKey = '__all_time__';\n", "", "remove all-time key")
sheet = replace_once(
    sheet,
    """  late final List<DateTime> availableMonths;
  late String selectedPeriodKey;
""",
    """  late final List<DateTime> availableMonths;
  late String selectedPeriodKey;
  late DateTimeRange selectedDateRange;
  PaymentReportPeriodMode selectedPeriodMode =
      PaymentReportPeriodMode.settlementMonth;
""",
    "sheet period mode state",
)
sheet = replace_once(
    sheet,
    """    selectedPeriodKey = _monthKey(initial);
  }
""",
    """    selectedPeriodKey = _monthKey(initial);
    selectedDateRange =
        widget.initialDateRange ??
        DateTimeRange(
          start: DateTime(initial.year, initial.month, 1),
          end: DateTime(initial.year, initial.month + 1, 0),
        );
  }
""",
    "sheet initial range",
)
sheet = replace_once(
    sheet,
    """  DateTime? get selectedMonth {
    if (selectedPeriodKey == _allTimeKey) return null;

    for (final month in availableMonths) {
""",
    """  DateTime? get selectedMonth {
    for (final month in availableMonths) {
""",
    "selected month all-time removal",
)
sheet = replace_once(
    sheet,
    "  List<String> get objectNames {\n",
    r'''  String _formatDate(DateTime value) {
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
''',
    "sheet date helpers",
)
sheet = replace_once(
    sheet,
    """      PaymentReportRequest(
        month: selectedMonth,
        employeeKey: selectedEmployeeKey == _allEmployeesKey
            ? null
            : selectedEmployeeKey,
        objectName: isAllObjectsScope(selectedObjectKey)
            ? null
            : selectedObjectKey,
      ),
""",
    """      PaymentReportRequest(
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
""",
    "sheet request",
)
sheet = replace_once(
    sheet,
    "                  'Сначала выбери объект или «Все объекты», затем период и сотрудника.',\n",
    "                  'Выбери объект, способ отбора периода и сотрудника.',\n",
    "sheet description",
)
sheet = replace_once(
    sheet,
    r'''                      DropdownButtonFormField<String>(
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
''',
    r'''                      Align(
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
                            selected: selectedPeriodMode ==
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
                            selected: selectedPeriodMode ==
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
                            selected: selectedPeriodMode ==
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
''',
    "sheet period controls",
)
sheet_path.write_text(sheet, encoding="utf-8")

export_path = Path("lib/features/payments/data/payment_report_exporter.dart")
exporter = export_path.read_text(encoding="utf-8")

exporter = replace_once(
    exporter,
    """class PaymentReportRequest {
  final DateTime? month;
  final String? employeeKey;
  final String? objectName;

  const PaymentReportRequest({
    required this.month,
    required this.employeeKey,
    this.objectName,
  });

  bool get isAllTime => month == null;
}
""",
    """enum PaymentReportPeriodMode { settlementMonth, paymentDateRange, allTime }

class PaymentReportRequest {
  final PaymentReportPeriodMode periodMode;
  final DateTime? month;
  final DateTime? paymentDateFrom;
  final DateTime? paymentDateTo;
  final String? employeeKey;
  final String? objectName;

  const PaymentReportRequest({
    this.periodMode = PaymentReportPeriodMode.settlementMonth,
    required this.month,
    this.paymentDateFrom,
    this.paymentDateTo,
    required this.employeeKey,
    this.objectName,
  });

  PaymentReportPeriodMode get effectivePeriodMode {
    if (periodMode == PaymentReportPeriodMode.paymentDateRange) {
      return PaymentReportPeriodMode.paymentDateRange;
    }
    if (periodMode == PaymentReportPeriodMode.allTime || month == null) {
      return PaymentReportPeriodMode.allTime;
    }
    return PaymentReportPeriodMode.settlementMonth;
  }

  bool get isAllTime =>
      effectivePeriodMode == PaymentReportPeriodMode.allTime;
}
""",
    "report request mode",
)
exporter = replace_once(
    exporter,
    """    final paymentRows = await _fetchPaymentRows(
      employeeIds: employeeIds,
      month: request.month,
    );
""",
    """    final paymentRows = await _fetchPaymentRows(
      employeeIds: employeeIds,
      request: request,
    );
""",
    "report fetch request",
)
exporter = replace_once(
    exporter,
    r'''  static Future<List<Map<String, dynamic>>> _fetchPaymentRows({
    required List<String> employeeIds,
    required DateTime? month,
  }) async {
    const fields =
        'employee_id, period_year, period_month, payment_date, amount, payment_type, comment';

    final result = <Map<String, dynamic>>[];

    for (var start = 0; start < employeeIds.length; start += 100) {
      final end = (start + 100) > employeeIds.length
          ? employeeIds.length
          : start + 100;
      final chunk = employeeIds.sublist(start, end);

      final List<dynamic> rows;

      if (month == null) {
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk);
      } else {
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk)
            .eq('period_year', month.year)
            .eq('period_month', month.month);
      }

      result.addAll(rows.map((row) => Map<String, dynamic>.from(row as Map)));
    }

    return result;
  }
''',
    r'''  static Future<List<Map<String, dynamic>>> _fetchPaymentRows({
    required List<String> employeeIds,
    required PaymentReportRequest request,
  }) async {
    const fields =
        'employee_id, period_year, period_month, payment_date, amount, payment_type, comment';

    final result = <Map<String, dynamic>>[];

    for (var start = 0; start < employeeIds.length; start += 100) {
      final end = (start + 100) > employeeIds.length
          ? employeeIds.length
          : start + 100;
      final chunk = employeeIds.sublist(start, end);
      final mode = request.effectivePeriodMode;
      final List<dynamic> rows;

      if (mode == PaymentReportPeriodMode.allTime) {
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk);
      } else if (mode == PaymentReportPeriodMode.paymentDateRange) {
        final from = request.paymentDateFrom;
        final to = request.paymentDateTo;
        if (from == null || to == null) {
          throw Exception('Не выбран промежуток дат выплаты');
        }
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk)
            .gte('payment_date', _isoDate(from))
            .lte('payment_date', _isoDate(to));
      } else {
        final month = request.month;
        if (month == null) {
          throw Exception('Не выбран расчётный месяц');
        }
        rows = await _client
            .from('payments')
            .select(fields)
            .inFilter('employee_id', chunk)
            .eq('period_year', month.year)
            .eq('period_month', month.month);
      }

      result.addAll(rows.map((row) => Map<String, dynamic>.from(row as Map)));
    }

    return result;
  }
''',
    "report fetch modes",
)
exporter = replace_once(
    exporter,
    "  static String _formatDate(DateTime date) {\n",
    r'''  static String _isoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _formatDate(DateTime date) {
''',
    "iso date helper",
)
exporter = replace_once(
    exporter,
    r'''    final period = request.month == null
        ? 'за_все_время'
        : '${request.month!.year}_${request.month!.month.toString().padLeft(2, '0')}';
''',
    r'''    final period = switch (request.effectivePeriodMode) {
      PaymentReportPeriodMode.allTime => 'за_все_время',
      PaymentReportPeriodMode.paymentDateRange =>
        'по_датам_${_isoDate(request.paymentDateFrom!)}_${_isoDate(request.paymentDateTo!)}',
      PaymentReportPeriodMode.settlementMonth =>
        '${request.month!.year}_${request.month!.month.toString().padLeft(2, '0')}',
    };
''',
    "report filename range",
)
export_path.write_text(exporter, encoding="utf-8")

Path("test/payments_desktop_date_report_contract_test.dart").write_text(
    r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payments use a real desktop workspace', () {
    final source = File(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    ).readAsStringSync();

    expect(source, contains('constraints.maxWidth >= 1120'));
    expect(source, contains('BoxConstraints(maxWidth: 1360)'));
    expect(source, contains('width: 360'));
    expect(source, contains('buildDesktopPaymentsBody'));
    expect(source, contains('buildCompactPaymentsBody'));
  });

  test('payment report supports actual payment date ranges', () {
    final sheet = File(
      'lib/features/payments/presentation/widgets/payment_report_sheet.dart',
    ).readAsStringSync();
    final exporter = File(
      'lib/features/payments/data/payment_report_exporter.dart',
    ).readAsStringSync();

    expect(sheet, contains('По датам выплаты'));
    expect(sheet, contains('showDateRangePicker'));
    expect(sheet, contains('PaymentReportPeriodMode.paymentDateRange'));
    expect(exporter, contains(".gte('payment_date', _isoDate(from))"));
    expect(exporter, contains(".lte('payment_date', _isoDate(to))"));
    expect(exporter, contains('по_датам_'));
  });
}
''',
    encoding="utf-8",
)
