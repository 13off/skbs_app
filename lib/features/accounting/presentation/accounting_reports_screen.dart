import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../models/employee.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/object_employee_scope.dart';
import '../../../widgets/premium_ui.dart';
import '../../ai/presentation/operational_audit_launcher_screen.dart';
import '../../payments/data/payment_report_exporter.dart';
import '../data/accounting_repository.dart';
import 'accounting_widgets.dart';

class AccountingReportsScreen extends StatefulWidget {
  const AccountingReportsScreen({super.key});

  @override
  State<AccountingReportsScreen> createState() => _AccountingReportsScreenState();
}

class _AccountingReportsScreenState extends State<AccountingReportsScreen> {
  late DateTime selectedMonth;
  late Future<List<AccountingPaymentRegisterRow>> registerFuture;
  bool isExporting = false;
  List<String> objectNames = const <String>[];
  String? selectedObjectScope;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    registerFuture = Future.value(
      const <AccountingPaymentRegisterRow>[],
    );
    loadObjects();
  }

  DateTime get firstDay => DateTime(selectedMonth.year, selectedMonth.month, 1);
  DateTime get lastDay =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0);
  String? get selectedObjectName =>
      selectedObjectNameFromScope(selectedObjectScope);

  Future<void> loadObjects() async {
    final names = await ObjectRepository.fetchObjectNames();
    if (!mounted) return;
    setState(() => objectNames = names);
  }

  Future<List<AccountingPaymentRegisterRow>> loadRegister({
    bool forceRefresh = false,
  }) {
    if (selectedObjectScope == null) {
      return Future.value(const <AccountingPaymentRegisterRow>[]);
    }
    return AccountingRepository.fetchPaymentRegister(
      startDate: firstDay,
      endDate: lastDay,
      objectName: selectedObjectName,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> refresh() async {
    final next = loadRegister(forceRefresh: true);
    setState(() => registerFuture = next);
    await next;
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
        1,
      );
      registerFuture = loadRegister(forceRefresh: true);
    });
  }

  String employeeKey(Employee employee) {
    final cleanName = employee.name.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    return cleanName.isNotEmpty
        ? cleanName
        : employee.id ?? employee.objectName;
  }

  Future<List<PaymentReportEmployeeOption>> reportEmployees() async {
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: selectedObjectName,
      includeFired: true,
    );
    final drafts = <String, _ReportEmployeeDraft>{};

    for (final employee in employees) {
      final id = employee.id?.trim();
      if (id == null || id.isEmpty) continue;
      final key = employeeKey(employee);
      final draft = drafts.putIfAbsent(
        key,
        () => _ReportEmployeeDraft(employee),
      );
      draft.employeeIds.add(id);
      if (employee.objectName.trim().isNotEmpty) {
        draft.objects.add(employee.objectName.trim());
      }
    }

    final result = drafts.entries.map((entry) {
      final draft = entry.value;
      final objects = draft.objects.toList()..sort();
      return PaymentReportEmployeeOption(
        key: entry.key,
        name: draft.employee.name,
        position: draft.employee.position,
        objectTitle: objects.isEmpty ? 'Все объекты' : objects.join(', '),
        employeeIds: draft.employeeIds.toList(),
        objectNames: objects,
      );
    }).toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<void> downloadPayments() async {
    if (isExporting || selectedObjectScope == null) return;
    setState(() => isExporting = true);
    try {
      final employees = await reportEmployees();
      if (employees.isEmpty) throw Exception('Нет сотрудников для отчёта');
      final count = await PaymentReportExporter.download(
        request: PaymentReportRequest(
          month: selectedMonth,
          employeeKey: null,
          objectName: selectedObjectName,
        ),
        employees: employees,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отчёт скачан. Строк выплат: $count')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка формирования отчёта: $error')),
      );
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  void openTimesheet() {
    if (selectedObjectScope == null) return;
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => PeriodTimesheetScreen(
          selectedObjectName: selectedObjectName,
          initialMonth: selectedMonth,
        ),
      ),
    );
  }

  void openAudit() {
    if (selectedObjectScope == null) return;
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => OperationalAuditLauncherScreen(
          initialMonth: selectedMonth,
          initialObjectName: selectedObjectName,
        ),
      ),
    );
  }

  Widget objectPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: DropdownButtonFormField<String>(
        initialValue: selectedObjectScope,
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
          ...objectNames.map(
            (name) => DropdownMenuItem<String>(value: name, child: Text(name)),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedObjectScope = value;
            registerFuture = loadRegister(forceRefresh: true);
          });
        },
      ),
    );
  }

  Widget monthPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => changeMonth(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Отчётный период',
                  style: TextStyle(
                    color: accountingMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  accountingMonth(selectedMonth),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => changeMonth(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget reportAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: PremiumWorkCard(
          radius: 23,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accountingSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accountingText),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: accountingMuted,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExporting && title == 'Отчёт по выплатам')
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: accountingMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget register(List<AccountingPaymentRegisterRow> rows) {
    final total = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final withoutReceipt = rows.where((row) => row.receiptCount == 0).length;
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Реестр выплат',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${rows.length} операций · ${accountingMoney(total)} · без чека: $withoutReceipt',
            style: const TextStyle(
              color: accountingMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('Выплат за выбранный период нет')),
            ),
          ...rows.take(20).map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                row.receiptCount == 0
                    ? Icons.receipt_long_outlined
                    : Icons.verified_outlined,
              ),
              title: Text(
                row.employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${accountingDate(row.paymentDate)} · ${row.objectName.isEmpty ? 'Без объекта' : row.objectName}',
              ),
              trailing: Text(
                accountingMoney(row.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Отчёты',
      subtitle: 'Выплаты, табели, начисления и подтверждающие документы',
      child: Column(
        children: [
          objectPanel(),
          const SizedBox(height: 14),
          monthPanel(),
          const SizedBox(height: 14),
          reportAction(
            icon: Icons.fact_check_outlined,
            title: 'Единый контроль',
            subtitle:
                'Найти расхождения табеля, начислений, выплат, чеков и объектов',
            onTap: selectedObjectScope == null ? null : openAudit,
          ),
          reportAction(
            icon: Icons.download_outlined,
            title: 'Отчёт по выплатам',
            subtitle: 'Скачать XLSX по всем сотрудникам за выбранный месяц',
            onTap: isExporting || selectedObjectScope == null
                ? null
                : downloadPayments,
          ),
          reportAction(
            icon: Icons.calendar_month_outlined,
            title: 'Табель и начисления',
            subtitle: 'Открыть общий табель, начисления и выгрузку Excel',
            onTap: selectedObjectScope == null ? null : openTimesheet,
          ),
          const SizedBox(height: 4),
          FutureBuilder<List<AccountingPaymentRegisterRow>>(
            future: registerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const PremiumWorkCard(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              if (snapshot.hasError) {
                return PremiumWorkCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('Не удалось загрузить реестр: ${snapshot.error}'),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: refresh,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (selectedObjectScope == null) {
                return const PremiumWorkCard(
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      'Сначала выберите объект или «Все объекты».',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return register(snapshot.data ?? const []);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportEmployeeDraft {
  final Employee employee;
  final Set<String> employeeIds = <String>{};
  final Set<String> objects = <String>{};

  _ReportEmployeeDraft(this.employee);
}
