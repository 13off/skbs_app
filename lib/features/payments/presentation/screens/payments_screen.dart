import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/app_adaptive_palette.dart';
import '../../../../app/app_ui_tokens.dart';
import '../../../../data/app_data_sync.dart';
import '../../../../data/attendance_repository.dart';
import '../../../../data/employee_repository.dart';
import '../../../../data/payment_repository.dart';
import '../../../../models/employee.dart';
import '../../../../models/period_timesheet_row.dart';
import '../../../../screens/add_payment_screen.dart';
import '../../../../screens/payment_history_screen.dart';
import '../../../../widgets/object_employee_scope.dart';
import '../../../../widgets/premium_ui.dart';
import '../../data/payment_report_exporter.dart';
import '../widgets/payment_report_sheet.dart';
import '../../../../navigation/app_page_route.dart';

class PaymentsScreen extends StatefulWidget {
  final String? selectedObjectName;

  const PaymentsScreen({super.key, this.selectedObjectName});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final searchController = TextEditingController();

  late DateTime selectedMonth;
  DateTimeRange? selectedRange;
  _PaymentAccountingMode accountingMode =
      _PaymentAccountingMode.settlementPeriod;
  _PaymentEmploymentFilter employmentFilter = _PaymentEmploymentFilter.all;
  List<_PaymentDisplayRow> rows = [];
  List<Employee> reportEmployees = [];

  bool isLoading = false;
  bool isExportingReport = false;
  String? errorText;
  int _loadGeneration = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    loadPaymentsData();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted ||
        !change.affectsAny(const <AppDataDomain>{
          AppDataDomain.attendance,
          AppDataDomain.payments,
          AppDataDomain.employees,
          AppDataDomain.objects,
        })) {
      return;
    }

    loadPaymentsData();
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

    if (month < 1 || month > monthNames.length) return 'Месяц';
    return monthNames[month - 1];
  }

  String get monthTitle {
    return '${monthName(selectedMonth.month)} ${selectedMonth.year}';
  }

  DateTime get periodStart =>
      selectedRange?.start ??
      DateTime(selectedMonth.year, selectedMonth.month, 1);

  DateTime get periodEnd =>
      selectedRange?.end ??
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

  String formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String get periodTitle {
    final range = selectedRange;
    if (range == null) return monthTitle;
    return '${formatDate(range.start)} — ${formatDate(range.end)}';
  }

  String formatMoney(num value) {
    final text = value.round().toString();
    final formatted = text.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$formatted ₽';
  }

  String normalizedEmployeeKey(Employee employee) {
    final cleanName = employee.name.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (cleanName.isNotEmpty) return cleanName;

    final cleanId = employee.id?.trim();
    if (cleanId != null && cleanId.isNotEmpty) return cleanId;

    return '${employee.position}_${employee.objectName}'.toLowerCase();
  }

  List<_PaymentDisplayRow> buildPaymentRows(
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
      final paidValue =
          employeeId.isNotEmpty && appliedPaymentIds.add(employeeId)
          ? paidByEmployeeId[employeeId] ?? 0.0
          : 0.0;
      draft.add(
        employee: row.employee,
        accruedValue: row.accrued,
        paidValue: paidValue,
      );
    }

    for (final employee in paymentEmployees) {
      final employeeId = employee.id?.trim() ?? '';
      if (employeeId.isEmpty || appliedPaymentIds.contains(employeeId)) {
        continue;
      }
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

  List<_PaymentDisplayRow> get filteredRows {
    final query = searchController.text.trim().toLowerCase();
    return rows.where((row) {
      final employee = row.employee;
      final employmentMatches = switch (employmentFilter) {
        _PaymentEmploymentFilter.all => true,
        _PaymentEmploymentFilter.active => employee.isActive,
        _PaymentEmploymentFilter.fired => !employee.isActive,
      };
      if (!employmentMatches) return false;
      if (query.isEmpty) return true;

      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          row.objectTitle.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> loadPaymentsData({
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
      final scopedEmployees = allEmployees
          .where((employee) {
            if (selectedObject == null ||
                selectedObject.isEmpty ||
                isAllObjectsScope(selectedObject)) {
              return true;
            }
            return employee.objectName.trim() == selectedObject;
          })
          .toList(growable: false);
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
          mode == _PaymentAccountingMode.settlementPeriod
              ? periodRows
              : const <PeriodTimesheetRow>[],
          paidByEmployeeId,
          paymentEmployees: scopedEmployees,
        );
        reportEmployees = scopedEmployees;
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

  Future<void> changeMonth(int offset) async {
    final targetMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + offset,
      1,
    );

    await loadPaymentsData(month: targetMonth);
  }

  Future<void> changeAccountingMode(_PaymentAccountingMode mode) async {
    if (mode == accountingMode || isLoading) return;
    setState(() {
      accountingMode = mode;
      selectedRange = null;
    });
    await loadPaymentsData(month: selectedMonth, forceRefresh: true);
  }

  Future<void> pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: periodStart, end: periodEnd),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035, 12, 31),
      helpText: 'Выберите промежуток выплат',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      saveText: 'Выбрать',
    );
    if (picked == null || !mounted) return;
    await loadPaymentsData(range: picked);
  }

  Future<void> resetToMonth() async {
    await loadPaymentsData(month: selectedMonth);
  }

  Future<void> openAddPayment({String? employeeId}) async {
    final result = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: monthTitle,
          initialEmployeeId: employeeId,
          initialObjectName: widget.selectedObjectName,
        ),
      ),
    );

    if (!mounted || result != true) return;
    await loadPaymentsData(forceRefresh: true);
  }

  Future<void> openPaymentHistory(_PaymentDisplayRow row) async {
    await Navigator.push<void>(
      context,
      AppPageRoute(
        builder: (_) => PaymentHistoryScreen(
          employee: row.employee,
          employeeIds: row.employeeIds,
        ),
      ),
    );

    if (!mounted) return;
    await loadPaymentsData(forceRefresh: true);
  }

  List<PaymentReportEmployeeOption> buildReportEmployeeOptions() {
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

  Future<void> openPaymentReport() async {
    if (isLoading || isExportingReport) return;

    final employeeOptions = buildReportEmployeeOptions();

    if (employeeOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет сотрудников для отчёта')),
      );
      return;
    }

    final request = await showPaymentReportSheet(
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

    if (!mounted || request == null) return;

    setState(() {
      isExportingReport = true;
    });

    try {
      final exportedRows = await PaymentReportExporter.download(
        request: request,
        employees: employeeOptions,
      );

      if (!mounted) return;

      final text = exportedRows == 0
          ? 'Таблица скачана. Выплат за выбранный период нет'
          : 'Отчёт скачан. Строк выплат: $exportedRows';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка формирования отчёта: $e')));
    } finally {
      if (mounted) {
        setState(() {
          isExportingReport = false;
        });
      }
    }
  }

  Widget buildMonthPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: isLoading ? null : () => changeMonth(-1),
            icon: Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Text(
                  accountingMode == _PaymentAccountingMode.settlementPeriod
                      ? 'Расчётный период'
                      : 'Дата фактической выплаты',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  periodTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: isLoading ? null : () => changeMonth(1),
            icon: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryPanel(List<_PaymentDisplayRow> visibleRows) {
    var totalAccrued = 0.0;
    var totalPaid = 0.0;
    var totalBalance = 0.0;
    for (final row in visibleRows) {
      totalAccrued += row.accrued;
      totalPaid += row.paid;
      totalBalance += row.balance;
    }

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(15),
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
          const SizedBox(height: 12),
          if (accountingMode == _PaymentAccountingMode.paymentDate)
            _MoneySummaryItem(
              title: 'Фактически выплачено',
              value: formatMoney(totalPaid),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Начислено',
                    value: formatMoney(totalAccrued),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneySummaryItem(
                    title: 'Выплачено за период',
                    value: formatMoney(totalPaid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MoneySummaryItem(
              title: totalBalance >= 0 ? 'Остаток' : 'Переплата',
              value: formatMoney(totalBalance.abs()),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildSearch() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО, должности или объекту',
        prefixIcon: Icon(Icons.search),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close),
              ),
        filled: true,
        fillColor: AppAdaptivePalette.inputSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: AppAdaptivePalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: AppAdaptivePalette.textPrimary,
            width: 1.3,
          ),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget buildPaymentFilters() {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                  changeAccountingMode(_PaymentAccountingMode.settlementPeriod);
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Все'),
                selected: employmentFilter == _PaymentEmploymentFilter.all,
                onSelected: (_) => setState(() {
                  employmentFilter = _PaymentEmploymentFilter.all;
                }),
              ),
              ChoiceChip(
                label: const Text('Работающие'),
                selected: employmentFilter == _PaymentEmploymentFilter.active,
                onSelected: (_) => setState(() {
                  employmentFilter = _PaymentEmploymentFilter.active;
                }),
              ),
              ChoiceChip(
                label: const Text('Уволенные'),
                selected: employmentFilter == _PaymentEmploymentFilter.fired,
                onSelected: (_) => setState(() {
                  employmentFilter = _PaymentEmploymentFilter.fired;
                }),
              ),
            ],
          ),
          if (accountingMode == _PaymentAccountingMode.paymentDate) ...[
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
        ],
      ),
    );
  }

  Widget buildPaymentCard(_PaymentDisplayRow row) {
    final employee = row.employee;
    final balance = row.balance;

    final Color balanceColor;
    final String balanceTitle;

    if (balance > 0) {
      balanceColor = AppAdaptivePalette.textPrimary;
      balanceTitle = 'Остаток';
    } else if (balance < 0) {
      balanceColor = AppAdaptivePalette.danger;
      balanceTitle = 'Переплата';
    } else {
      balanceColor = AppAdaptivePalette.success;
      balanceTitle = 'Закрыто';
    }

    return PremiumWorkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      radius: 23,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: AppAdaptivePalette.textPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${employee.position} • ${row.objectTitle}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (accountingMode == _PaymentAccountingMode.paymentDate)
            _MoneyLine(
              title: 'Фактически выплачено',
              value: formatMoney(row.paid),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MoneyLine(
                    title: 'Начислено',
                    value: formatMoney(row.accrued),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MoneyLine(
                    title: 'Выплачено за период',
                    value: formatMoney(row.paid),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MoneyLine(
              title: balanceTitle,
              value: formatMoney(balance.abs()),
              valueColor: balanceColor,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: row.employeeIds.isEmpty || isLoading
                  ? null
                  : () => openPaymentHistory(row),
              icon: Icon(Icons.history, size: 18),
              label: Text('История выплат'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildReportAction() {
    if (isExportingReport) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return TextButton.icon(
      onPressed: isLoading ? null : openPaymentReport,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(Icons.download_outlined, size: 18),
      label: const Text('Отчёт'),
    );
  }

  Widget buildAddAction() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 10),
      child: FilledButton.tonalIcon(
        onPressed: isLoading ? null : () => openAddPayment(),
        style: FilledButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(Icons.add, size: 18),
        label: const Text('Добавить'),
      ),
    );
  }

  Widget buildDesktopSummaryPanel(List<_PaymentDisplayRow> visibleRows) {
    var totalAccrued = 0.0;
    var totalPaid = 0.0;
    var totalBalance = 0.0;
    for (final row in visibleRows) {
      totalAccrued += row.accrued;
      totalPaid += row.paid;
      totalBalance += row.balance;
    }

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
      buildSummaryPanel(visibleRows),
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
    final leading = <Widget>[
      buildMonthPanel(),
      const SizedBox(height: 18),
      buildDesktopSummaryPanel(visibleRows),
      const SizedBox(height: 18),
      buildSearch(),
      const SizedBox(height: 14),
      ...buildPaymentStatus(visibleRows),
    ];
    final rowCount = isLoading && visibleRows.isEmpty ? 0 : visibleRows.length;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => loadPaymentsData(forceRefresh: true),
                child: ListView.builder(
                  // Flutter 3.44 deprecates this field before exposing its replacement.
                  // ignore: deprecated_member_use
                  cacheExtent: 800,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppUi.pageDesktopHorizontalPadding,
                    22,
                    0,
                    132,
                  ),
                  itemCount: leading.length + rowCount,
                  itemBuilder: (context, index) {
                    final child = index < leading.length
                        ? leading[index]
                        : buildPaymentCard(visibleRows[index - leading.length]);
                    return RepaintBoundary(child: child);
                  },
                ),
              ),
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 360,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  22,
                  AppUi.pageDesktopHorizontalPadding,
                  132,
                ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
}

enum _PaymentAccountingMode { settlementPeriod, paymentDate }

enum _PaymentEmploymentFilter { all, active, fired }

class _PaymentDisplayRow {
  final Employee employee;
  final String objectTitle;
  final List<String> employeeIds;
  final List<String> objectNames;
  final double accrued;
  final double paid;

  const _PaymentDisplayRow({
    required this.employee,
    required this.objectTitle,
    required this.employeeIds,
    required this.objectNames,
    required this.accrued,
    required this.paid,
  });

  double get balance => accrued - paid;
}

class _PaymentDisplayDraft {
  final Employee firstEmployee;
  final Set<String> employeeIds = {};
  final Set<String> objectNames = {};
  double accrued = 0;
  double paid = 0;

  _PaymentDisplayDraft(this.firstEmployee);

  void add({
    required Employee employee,
    required double accruedValue,
    required double paidValue,
  }) {
    final employeeId = employee.id?.trim();
    final objectName = employee.objectName.trim();

    if (employeeId != null && employeeId.isNotEmpty) {
      employeeIds.add(employeeId);
    }

    if (objectName.isNotEmpty) {
      objectNames.add(objectName);
    }

    accrued += accruedValue;
    paid += paidValue;
  }

  String get objectTitle {
    final objects = objectNames.toList()..sort();

    if (objects.isEmpty) return 'Все объекты';
    if (objects.length == 1) return objects.first;
    return objects.join(', ');
  }

  _PaymentDisplayRow toRow() {
    final title = objectTitle;
    final employee = Employee(
      firstEmployee.name,
      firstEmployee.position,
      firstEmployee.status,
      id: employeeIds.isEmpty ? firstEmployee.id : employeeIds.first,
      phone: firstEmployee.phone,
      objectName: title,
      dailyRate: firstEmployee.dailyRate,
      isActive: firstEmployee.isActive,
      comment: firstEmployee.comment,
    );

    return _PaymentDisplayRow(
      employee: employee,
      objectTitle: title,
      employeeIds: employeeIds.toList(),
      objectNames: objectNames.toList()..sort(),
      accrued: accrued,
      paid: paid,
    );
  }
}

class _PaymentReportOptionDraft {
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
  const _MoneySummaryItem({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({required this.title, required this.value, this.valueColor});

  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
