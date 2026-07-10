import 'package:flutter/material.dart';

import '../data/attendance_repository.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import 'add_payment_screen.dart';
import 'payment_history_screen.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final searchController = TextEditingController();

  late DateTime selectedMonth;

  List<_PaymentDisplayRow> rows = [];

  bool isLoading = false;
  String? errorText;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);

    loadPaymentsData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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

  Future<void> loadPaymentsData() async {
    final generation = ++_loadGeneration;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await AttendanceRepository.fetchMonthlyTimesheet(
        year: selectedMonth.year,
        month: selectedMonth.month,
      );

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
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
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
        1,
      );
      rows = [];
    });

    await loadPaymentsData();
  }

  Future<void> openAddPayment({String? employeeId}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: monthTitle,
          initialEmployeeId: employeeId,
        ),
      ),
    );

    if (result == true) {
      await loadPaymentsData();
    }
  }

  Future<void> openPaymentHistory(_PaymentDisplayRow row) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentHistoryScreen(
          employee: row.employee,
          employeeIds: row.employeeIds,
        ),
      ),
    );

    await loadPaymentsData();
  }

  Widget buildMonthPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: isLoading
                ? null
                : () {
                    changeMonth(-1);
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Период выплат',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: isLoading
                ? null
                : () {
                    changeMonth(1);
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget buildPaymentCard(_PaymentDisplayRow row) {
    final employee = row.employee;
    final balance = row.balance;

    final Color balanceColor;
    final String balanceTitle;

    if (balance > 0) {
      balanceColor = Colors.orange.shade700;
      balanceTitle = 'Остаток';
    } else if (balance < 0) {
      balanceColor = Colors.red.shade700;
      balanceTitle = 'Переплата';
    } else {
      balanceColor = Colors.green.shade700;
      balanceTitle = 'Закрыто';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            employee.name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${employee.position} • ${row.objectTitle}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
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
                  : () {
                      openPaymentHistory(row);
                    },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('История выплат'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRows = filteredRows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Выплаты'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: isLoading
                  ? null
                  : () {
                      openAddPayment();
                    },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadPaymentsData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (!isLoading && visibleRows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Сотрудники не найдены',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else
              ...visibleRows.map(buildPaymentCard),
          ],
        ),
      ),
    );
  }
}

class _PaymentDisplayRow {
  final Employee employee;
  final String objectTitle;
  final List<String> employeeIds;
  final double accrued;
  final double paid;

  const _PaymentDisplayRow({
    required this.employee,
    required this.objectTitle,
    required this.employeeIds,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
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
