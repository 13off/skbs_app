import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import '../../../../app/app_adaptive_palette.dart';
import '../../../../data/app_data_sync.dart';
import '../../../../data/attendance_repository.dart';
import '../../../../models/employee.dart';
import '../../../../models/monthly_timesheet_row.dart';
import '../../../../screens/add_payment_screen.dart';
import '../../../../screens/payment_history_screen.dart';
import '../../../../widgets/premium_ui.dart';
import '../../data/payment_report_exporter.dart';
import '../widgets/payment_report_sheet.dart';

class PaymentsScreen extends StatefulWidget {
  final String? selectedObjectName;

  const PaymentsScreen({super.key, this.selectedObjectName});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final searchController = TextEditingController();

  late DateTime selectedMonth;
  List<_PaymentDisplayRow> rows = [];

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

    loadPaymentsData(forceRefresh: true);
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

  List<_PaymentDisplayRow> buildPaymentRows(List<MonthlyTimesheetRow> source) {
    final drafts = <String, _PaymentDisplayDraft>{};

    for (final row in source) {
      final key = normalizedEmployeeKey(row.employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _PaymentDisplayDraft(row.employee),
      );

      draft.add(row);
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
    if (query.isEmpty) return rows;

    return rows.where((row) {
      final employee = row.employee;

      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          row.objectTitle.toLowerCase().contains(query);
    }).toList();
  }

  double get totalAccrued {
    return filteredRows.fold<double>(0, (sum, row) => sum + row.accrued);
  }

  double get totalPaid {
    return filteredRows.fold<double>(0, (sum, row) => sum + row.paid);
  }

  double get totalBalance {
    return filteredRows.fold<double>(0, (sum, row) => sum + row.balance);
  }

  Future<void> loadPaymentsData({
    DateTime? month,
    bool forceRefresh = false,
  }) async {
    final generation = ++_loadGeneration;
    final requestedMonth = month ?? selectedMonth;
    final targetMonth = DateTime(requestedMonth.year, requestedMonth.month, 1);

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await AttendanceRepository.fetchMonthlyTimesheet(
        year: targetMonth.year,
        month: targetMonth.month,
        objectName: widget.selectedObjectName,
        includeFired: true,
        forceRefresh: forceRefresh,
      );

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        selectedMonth = targetMonth;
        rows = buildPaymentRows(result);
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

  Future<void> openAddPayment({String? employeeId}) async {
    final result = await Navigator.push<bool>(
      context,
      CupertinoPageRoute(
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
      CupertinoPageRoute(
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
                  'Период выплат',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  monthTitle,
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

  Widget buildSummaryPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сводка за период',
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
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
                  title: 'Выплачено',
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
                  title: 'Выплачено',
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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                cacheExtent: 700,
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
}

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

  void add(MonthlyTimesheetRow row) {
    final employee = row.employee;
    final employeeId = employee.id?.trim();
    final objectName = employee.objectName.trim();

    if (employeeId != null && employeeId.isNotEmpty) {
      employeeIds.add(employeeId);
    }

    if (objectName.isNotEmpty) {
      objectNames.add(objectName);
    }

    accrued += row.accrued;
    paid += row.paid;
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
