from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    if old not in content:
        raise SystemExit(f'Marker not found in {path}: {old[:160]!r}')
    write(path, content.replace(old, new, 1))


# --- Add payment: editable settlement month, unchanged payment types ---
add_payment = 'lib/screens/add_payment_screen.dart'
replace_once(
    add_payment,
    """  String? selectedObjectName;
  String? selectedEmployeeId;
  DateTime paymentDate = DateTime.now();

  String selectedPaymentType = 'advance';
""",
    """  String? selectedObjectName;
  String? selectedEmployeeId;
  DateTime paymentDate = DateTime.now();
  late DateTime settlementMonth;

  String selectedPaymentType = 'advance';
""",
)
replace_once(
    add_payment,
    """    final initialObject = widget.initialObjectName?.trim();
    selectedObjectName = initialObject == null || initialObject.isEmpty
""",
    """    settlementMonth = DateTime(widget.periodYear, widget.periodMonth, 1);
    final initialObject = widget.initialObjectName?.trim();
    selectedObjectName = initialObject == null || initialObject.isEmpty
""",
)
replace_once(
    add_payment,
    """  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  double? parseAmount() {
""",
    """  String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
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
    if (month < 1 || month > names.length) return 'Месяц';
    return names[month - 1];
  }

  String get settlementPeriodTitle =>
      '${monthName(settlementMonth.month)} ${settlementMonth.year}';

  Future<void> pickSettlementPeriod() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var year = settlementMonth.year;
        var month = settlementMonth.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Расчётный период'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Предыдущий год',
                          onPressed: () => setDialogState(() => year -= 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            '$year',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Следующий год',
                          onPressed: () => setDialogState(() => year += 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(12, (index) {
                        final value = index + 1;
                        return ChoiceChip(
                          label: Text(monthName(value)),
                          selected: month == value,
                          onSelected: (_) {
                            setDialogState(() => month = value);
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, DateTime(year, month, 1));
                  },
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => settlementMonth = picked);
  }

  double? parseAmount() {
""",
)
replace_once(
    add_payment,
    """        periodYear: widget.periodYear,
        periodMonth: widget.periodMonth,
""",
    """        periodYear: settlementMonth.year,
        periodMonth: settlementMonth.month,
""",
)
replace_once(
    add_payment,
    """                const Text(
                  'Период выплаты',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(widget.periodTitle, style: const TextStyle(fontSize: 16)),
""",
    """                const Text(
                  'Расчётный период',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'За какой месяц относится эта выплата',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : pickSettlementPeriod,
                    icon: const Icon(Icons.event_note_outlined),
                    label: Text('За период: $settlementPeriodTitle'),
                  ),
                ),
""",
)

# --- Payment history: explicit labels for both dates ---
history = 'lib/screens/payment_history_screen.dart'
replace_once(
    history,
    """          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 6),
              Text(
                formatDate(payment.paymentDate),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.event_note_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  periodTitle(payment),
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
""",
    """          Row(
            children: [
              const Icon(Icons.calendar_month, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Выплачено: ${formatDate(payment.paymentDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(Icons.event_note_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'За период: ${periodTitle(payment)}',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
""",
)

# --- Payments screen: settlement-period balance vs actual cash movement ---
payments = 'lib/features/payments/presentation/screens/payments_screen.dart'
replace_once(
    payments,
    """import '../../../../data/attendance_repository.dart';
import '../../../../data/payment_repository.dart';
""",
    """import '../../../../data/attendance_repository.dart';
import '../../../../data/employee_repository.dart';
import '../../../../data/payment_repository.dart';
""",
)
replace_once(
    payments,
    """import '../../../../widgets/premium_ui.dart';
""",
    """import '../../../../widgets/object_employee_scope.dart';
import '../../../../widgets/premium_ui.dart';
""",
)
replace_once(
    payments,
    """  DateTimeRange? selectedRange;
  _PaymentEmploymentFilter employmentFilter = _PaymentEmploymentFilter.all;
""",
    """  DateTimeRange? selectedRange;
  _PaymentAccountingMode accountingMode =
      _PaymentAccountingMode.settlementPeriod;
  _PaymentEmploymentFilter employmentFilter = _PaymentEmploymentFilter.all;
""",
)
replace_once(
    payments,
    """  List<_PaymentDisplayRow> buildPaymentRows(
    List<PeriodTimesheetRow> source,
    Map<String, double> paidByEmployeeId,
  ) {
    final drafts = <String, _PaymentDisplayDraft>{};

    for (final row in source) {
      final key = normalizedEmployeeKey(row.employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _PaymentDisplayDraft(row.employee),
      );
      final employeeId = row.employee.id?.trim() ?? '';
      draft.add(
        employee: row.employee,
        accruedValue: row.accrued,
        paidValue: employeeId.isEmpty ? 0 : paidByEmployeeId[employeeId] ?? 0,
      );
    }

    final result = drafts.values
        .map((draft) => draft.toRow())
        .where((row) => row.employee.name.trim().isNotEmpty)
        .toList();

    result.sort((a, b) => a.employee.name.compareTo(b.employee.name));
    return result;
  }
""",
    """  List<_PaymentDisplayRow> buildPaymentRows(
    List<PeriodTimesheetRow> source,
    Map<String, double> paidByEmployeeId, {
    List<Employee> paymentEmployees = const <Employee>[],
  }) {
    final drafts = <String, _PaymentDisplayDraft>{};
    final appliedPaymentIds = <String>{};

    for (final row in source) {
      final key = normalizedEmployeeKey(row.employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _PaymentDisplayDraft(row.employee),
      );
      final employeeId = row.employee.id?.trim() ?? '';
      final paidValue = employeeId.isNotEmpty && appliedPaymentIds.add(employeeId)
          ? paidByEmployeeId[employeeId] ?? 0
          : 0;
      draft.add(
        employee: row.employee,
        accruedValue: row.accrued,
        paidValue: paidValue,
      );
    }

    for (final employee in paymentEmployees) {
      final employeeId = employee.id?.trim() ?? '';
      if (employeeId.isEmpty || appliedPaymentIds.contains(employeeId)) continue;
      final paidValue = paidByEmployeeId[employeeId];
      if (paidValue == null || paidValue == 0) continue;
      appliedPaymentIds.add(employeeId);
      final key = normalizedEmployeeKey(employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _PaymentDisplayDraft(employee),
      );
      draft.add(employee: employee, accruedValue: 0, paidValue: paidValue);
    }

    final result = drafts.values
        .map((draft) => draft.toRow())
        .where((row) => row.employee.name.trim().isNotEmpty)
        .toList();

    result.sort((a, b) => a.employee.name.compareTo(b.employee.name));
    return result;
  }
""",
)
start = read(payments).index('  Future<void> loadPaymentsData({')
end = read(payments).index('  Future<void> changeMonth(', start)
content = read(payments)
new_loader = """  Future<void> loadPaymentsData({
    DateTime? month,
    DateTimeRange? range,
    bool forceRefresh = false,
  }) async {
    final generation = ++_loadGeneration;
    final mode = accountingMode;
    final targetRange = mode == _PaymentAccountingMode.paymentDate
        ? range ?? (month == null ? selectedRange : null)
        : null;
    final targetMonth = month != null
        ? DateTime(month.year, month.month, 1)
        : targetRange != null
        ? DateTime(targetRange.start.year, targetRange.start.month, 1)
        : selectedMonth;
    final startDate =
        targetRange?.start ?? DateTime(targetMonth.year, targetMonth.month, 1);
    final endDate =
        targetRange?.end ??
        DateTime(targetMonth.year, targetMonth.month + 1, 0);

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await Future.wait<dynamic>([
        AttendanceRepository.fetchPeriodTimesheet(
          startDate: startDate,
          endDate: endDate,
          objectName: widget.selectedObjectName,
          includeFired: true,
          forceRefresh: forceRefresh,
        ),
        EmployeeRepository.fetchEmployees(includeFired: true),
      ]);
      final periodRows = result[0] as List<PeriodTimesheetRow>;
      final allEmployees = result[1] as List<Employee>;
      final selectedObject = widget.selectedObjectName?.trim();
      final scopedEmployees = allEmployees.where((employee) {
        if (selectedObject == null ||
            selectedObject.isEmpty ||
            isAllObjectsScope(selectedObject)) {
          return true;
        }
        return employee.objectName.trim() == selectedObject;
      }).toList(growable: false);
      final employeeIds = <String>{
        ...periodRows
            .map((row) => row.employee.id?.trim() ?? '')
            .where((id) => id.isNotEmpty),
        ...scopedEmployees
            .map((employee) => employee.id?.trim() ?? '')
            .where((id) => id.isNotEmpty),
      }.toList(growable: false);
      final paymentRows = await PaymentRepository.fetchPaymentsForEmployees(
        employeeIds,
        forceRefresh: forceRefresh,
      );
      final paidByEmployeeId = <String, double>{};
      final cleanStart = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);
      for (final payment in paymentRows) {
        final matches = mode == _PaymentAccountingMode.settlementPeriod
            ? payment.periodYear == targetMonth.year &&
                  payment.periodMonth == targetMonth.month
            : () {
                final date = DateTime(
                  payment.paymentDate.year,
                  payment.paymentDate.month,
                  payment.paymentDate.day,
                );
                return !date.isBefore(cleanStart) && !date.isAfter(cleanEnd);
              }();
        if (!matches) continue;
        paidByEmployeeId[payment.employeeId] =
            (paidByEmployeeId[payment.employeeId] ?? 0) + payment.amount;
      }

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        selectedMonth = targetMonth;
        selectedRange = targetRange;
        rows = buildPaymentRows(
          periodRows,
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        errorText = 'Ошибка загрузки выплат: $e';
      });
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

"""
write(payments, content[:start] + new_loader + content[end:])
replace_once(
    payments,
    """  Future<void> pickPeriod() async {
""",
    """  Future<void> changeAccountingMode(_PaymentAccountingMode mode) async {
    if (mode == accountingMode || isLoading) return;
    setState(() {
      accountingMode = mode;
      selectedRange = null;
    });
    await loadPaymentsData(month: selectedMonth, forceRefresh: true);
  }

  Future<void> pickPeriod() async {
""",
)
replace_once(
    payments,
    """                  'Период выплат',
""",
    """                  accountingMode == _PaymentAccountingMode.settlementPeriod
                      ? 'Расчётный период'
                      : 'Дата фактической выплаты',
""",
)
replace_once(
    payments,
    """            'Сводка за период',
""",
    """            accountingMode == _PaymentAccountingMode.settlementPeriod
                ? 'Сводка за расчётный период'
                : 'Движение денег за период',
""",
)
replace_once(
    payments,
    """          Text(
            'Показывать сотрудников',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
""",
    """          Text(
            'Режим учёта',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('За расчётный период'),
                selected:
                    accountingMode == _PaymentAccountingMode.settlementPeriod,
                onSelected: (_) {
                  changeAccountingMode(
                    _PaymentAccountingMode.settlementPeriod,
                  );
                },
              ),
              ChoiceChip(
                label: const Text('По дате выплаты'),
                selected: accountingMode == _PaymentAccountingMode.paymentDate,
                onSelected: (_) {
                  changeAccountingMode(_PaymentAccountingMode.paymentDate);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Показывать сотрудников',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
""",
)
replace_once(
    payments,
    """          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : pickPeriod,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    selectedRange == null
                        ? 'Выбрать промежуток'
                        : 'Изменить промежуток',
                  ),
                ),
              ),
              if (selectedRange != null) ...[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Вернуться к месяцу',
                  onPressed: isLoading ? null : resetToMonth,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ],
          ),
""",
    """          if (accountingMode == _PaymentAccountingMode.paymentDate) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : pickPeriod,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      selectedRange == null
                          ? 'Выбрать промежуток дат'
                          : 'Изменить промежуток дат',
                    ),
                  ),
                ),
                if (selectedRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Вернуться к месяцу',
                    onPressed: isLoading ? null : resetToMonth,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ],
              ],
            ),
          ],
""",
)
replace_once(
    payments,
    """enum _PaymentEmploymentFilter { all, active, fired }
""",
    """enum _PaymentAccountingMode { settlementPeriod, paymentDate }

enum _PaymentEmploymentFilter { all, active, fired }
""",
)

# --- Focused regression contract ---
test_path = 'test/payment_settlement_period_contract_test.dart'
write(
    test_path,
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('payment keeps settlement period separate from actual date', () {
    final add = source('lib/screens/add_payment_screen.dart');
    final repository = source('lib/data/payment_repository.dart');
    final history = source('lib/screens/payment_history_screen.dart');

    expect(add, contains('late DateTime settlementMonth'));
    expect(add, contains("label: Text('За период: \\$settlementPeriodTitle')"));
    expect(add, contains('periodYear: settlementMonth.year'));
    expect(add, contains('periodMonth: settlementMonth.month'));
    expect(repository, contains("'period_year': periodYear"));
    expect(repository, contains("'period_month': periodMonth"));
    expect(repository, contains("'payment_date': dateKey(paymentDate)"));
    expect(history, contains("'Выплачено: \\${formatDate(payment.paymentDate)}'"));
    expect(history, contains("'За период: \\${periodTitle(payment)}'"));
  });

  test('existing payment types remain unchanged', () {
    final add = source('lib/screens/add_payment_screen.dart');
    expect(add, contains("'advance': 'Аванс'"));
    expect(add, contains("'salary': 'Заработная плата'"));
    expect(add, contains("'fine': 'Штраф'"));
  });

  test('payments screen supports settlement and cash-date modes', () {
    final screen = source(
      'lib/features/payments/presentation/screens/payments_screen.dart',
    );
    expect(screen, contains('_PaymentAccountingMode.settlementPeriod'));
    expect(screen, contains('_PaymentAccountingMode.paymentDate'));
    expect(screen, contains('payment.periodYear == targetMonth.year'));
    expect(screen, contains('payment.periodMonth == targetMonth.month'));
    expect(screen, contains('payment.paymentDate.year'));
    expect(screen, contains("label: const Text('За расчётный период')"));
    expect(screen, contains("label: const Text('По дате выплаты')"));
  });
}
""",
)
