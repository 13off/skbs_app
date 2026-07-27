import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../models/employee.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../../../widgets/object_employee_scope.dart';
import '../../../widgets/premium_ui.dart';
import '../../payments/data/payment_report_exporter.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_reports_screen.dart';
import 'accounting_widgets.dart';

class AdaptiveAccountingReportsScreen extends StatelessWidget {
  const AdaptiveAccountingReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return const AccountingReportsScreen();
        }
        return const _DesktopAccountingReportsScreen();
      },
    );
  }
}

class _DesktopAccountingReportsScreen extends StatefulWidget {
  const _DesktopAccountingReportsScreen();

  @override
  State<_DesktopAccountingReportsScreen> createState() =>
      _DesktopAccountingReportsScreenState();
}

class _DesktopAccountingReportsScreenState
    extends State<_DesktopAccountingReportsScreen> {
  final searchController = TextEditingController();
  late DateTime selectedMonth;
  late Future<List<AccountingPaymentRegisterRow>> registerFuture;
  StreamSubscription<AppDataChange>? subscription;
  List<String> objectNames = const <String>[];
  String? selectedObjectScope;
  String receiptFilter = 'all';
  bool isExporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    registerFuture = Future.value(const <AccountingPaymentRegisterRow>[]);
    loadObjects();
    subscription = AppDataSync.changes.listen((change) {
      if (!mounted || selectedObjectScope == null) return;
      if (change.affectsAny(const <AppDataDomain>{
        AppDataDomain.payments,
        AppDataDomain.employees,
        AppDataDomain.objects,
        AppDataDomain.attendance,
      })) {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
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
    return cleanName.isNotEmpty ? cleanName : employee.id ?? employee.objectName;
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
        ),
      ),
    );
  }

  List<AccountingPaymentRegisterRow> visibleRows(
    List<AccountingPaymentRegisterRow> rows,
  ) {
    final query = searchController.text.trim().toLowerCase();
    return rows.where((row) {
      if (receiptFilter == 'missing' && row.receiptCount > 0) return false;
      if (receiptFilter == 'confirmed' && row.receiptCount == 0) return false;
      if (query.isEmpty) return true;
      return '${row.employeeName} ${row.objectName} ${row.paymentType} ${row.comment}'
          .toLowerCase()
          .contains(query);
    }).toList();
  }

  String paymentType(String value) {
    switch (value) {
      case 'advance':
        return 'Аванс';
      case 'salary':
        return 'Зарплата';
      case 'final':
        return 'Окончательный расчёт';
      default:
        return value.trim().isEmpty ? 'Выплата' : value;
    }
  }

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        IconButton.filledTonal(
          tooltip: 'Предыдущий месяц',
          onPressed: () => changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 150),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: specialistSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: specialistLine),
          ),
          child: Text(
            accountingMonth(selectedMonth),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Следующий месяц',
          onPressed: () => changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        OutlinedButton.icon(
          onPressed: selectedObjectScope == null ? null : openTimesheet,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Табель и начисления'),
        ),
        FilledButton.icon(
          onPressed: isExporting || selectedObjectScope == null
              ? null
              : downloadPayments,
          icon: isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: const Text('Скачать XLSX'),
        ),
      ],
    );
  }

  Widget filters() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: selectedObjectScope,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Объект',
                hintText: 'Выберите объект',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: allObjectsScopeValue,
                  child: Text('Все объекты'),
                ),
                ...objectNames.map(
                  (name) => DropdownMenuItem<String>(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedObjectScope = value;
                  registerFuture = loadRegister(forceRefresh: true);
                });
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: searchController,
              enabled: selectedObjectScope != null,
              decoration: const InputDecoration(
                hintText: 'Сотрудник, тип выплаты или комментарий',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: receiptFilter,
              decoration: const InputDecoration(
                labelText: 'Подтверждение',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все выплаты')),
                DropdownMenuItem(value: 'missing', child: Text('Без чека')),
                DropdownMenuItem(
                  value: 'confirmed',
                  child: Text('С подтверждением'),
                ),
              ],
              onChanged: selectedObjectScope == null
                  ? null
                  : (value) {
                      setState(() => receiptFilter = value ?? 'all');
                    },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: selectedObjectScope == null ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget summary(List<AccountingPaymentRegisterRow> rows) {
    final total = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final missing = rows.where((row) => row.receiptCount == 0).length;
    final employees = rows.map((row) => row.employeeName).toSet().length;
    final confirmed = rows.length - missing;

    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.payments_outlined,
            label: 'Сумма выплат',
            value: accountingMoney(total),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.receipt_long_outlined,
            label: 'Операций',
            value: '${rows.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.groups_outlined,
            label: 'Сотрудников',
            value: '$employees',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.verified_outlined,
            label: 'Подтверждено',
            value: '$confirmed',
            hint: 'Без чека: $missing',
            accent: missing > 0 ? specialistWarning : specialistSuccess,
          ),
        ),
      ],
    );
  }

  Widget table(List<AccountingPaymentRegisterRow> rows) {
    return SpecialistDesktopTable(
      minWidth: 1200,
      columns: const [
        SpecialistTableColumn('Дата', flex: 2),
        SpecialistTableColumn('Сотрудник', flex: 3),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Сумма', flex: 2),
        SpecialistTableColumn('Подтверждение', flex: 2),
        SpecialistTableColumn('Комментарий', flex: 4),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              cells: [
                specialistCellText(
                  accountingDate(row.paymentDate),
                  maxLines: 1,
                ),
                specialistCellText(
                  row.employeeName,
                  weight: FontWeight.w900,
                ),
                specialistCellText(
                  row.objectName,
                  color: specialistMuted,
                ),
                specialistCellText(paymentType(row.paymentType), maxLines: 1),
                specialistCellText(
                  accountingMoney(row.amount),
                  weight: FontWeight.w900,
                ),
                SpecialistStatusPill(
                  label: row.receiptCount == 0
                      ? 'Нет чека'
                      : 'Файлов: ${row.receiptCount}',
                  color: row.receiptCount == 0
                      ? specialistDanger
                      : specialistSuccess,
                  icon: row.receiptCount == 0
                      ? Icons.receipt_long_outlined
                      : Icons.verified_outlined,
                ),
                specialistCellText(
                  row.comment,
                  color: specialistMuted,
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AccountingPaymentRegisterRow>>(
      future: registerFuture,
      builder: (context, snapshot) {
        final children = <Widget>[filters(), const SizedBox(height: 16)];
        if (selectedObjectScope == null) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.apartment_outlined,
              title: 'Выберите объект',
              description:
                  'Можно выбрать конкретный объект или пункт «Все объекты».',
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.summarize_outlined,
              title: 'Формируем финансовый реестр',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить реестр',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final rows = visibleRows(
            snapshot.data ?? const <AccountingPaymentRegisterRow>[],
          );
          children.add(summary(rows));
          children.add(const SizedBox(height: 18));
          if (rows.isEmpty) {
            children.add(
              const SpecialistMessageCard(
                icon: Icons.receipt_long_outlined,
                title: 'Выплаты не найдены',
                description: 'Измените период, объект или фильтры.',
              ),
            );
          } else {
            children.add(table(rows));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-reports',
          title: 'Финансовые отчёты',
          subtitle:
              'Реестр выплат, подтверждающие документы, табель и выгрузка XLSX',
          trailing: actions(),
          onRefresh: selectedObjectScope == null ? null : refresh,
          children: children,
        );
      },
    );
  }
}

class _ReportEmployeeDraft {
  final Employee employee;
  final Set<String> employeeIds = <String>{};
  final Set<String> objects = <String>{};

  _ReportEmployeeDraft(this.employee);
}
