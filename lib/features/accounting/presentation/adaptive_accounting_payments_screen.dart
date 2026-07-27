import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/monthly_timesheet_row.dart';
import '../../../screens/add_payment_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../../payments/presentation/screens/payments_screen.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_widgets.dart';

class AdaptiveAccountingPaymentsScreen extends StatelessWidget {
  const AdaptiveAccountingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return const PaymentsScreen();
        }
        return const _DesktopAccountingPaymentsScreen();
      },
    );
  }
}

class _DesktopAccountingPaymentsScreen extends StatefulWidget {
  const _DesktopAccountingPaymentsScreen();

  @override
  State<_DesktopAccountingPaymentsScreen> createState() =>
      _DesktopAccountingPaymentsScreenState();
}

class _DesktopAccountingPaymentsScreenState
    extends State<_DesktopAccountingPaymentsScreen> {
  final searchController = TextEditingController();
  late DateTime selectedMonth;
  late Future<_PaymentsWorkspaceData> future;
  StreamSubscription<AppDataChange>? subscription;
  String? objectName;
  String receiptFilter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (!mounted ||
          !change.affectsAny(const <AppDataDomain>{
            AppDataDomain.attendance,
            AppDataDomain.payments,
            AppDataDomain.employees,
            AppDataDomain.objects,
          })) {
        return;
      }
      refresh();
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

  Future<_PaymentsWorkspaceData> load({bool forceRefresh = false}) async {
    final results = await Future.wait<dynamic>([
      AccountingRepository.fetchBalanceRows(
        month: selectedMonth,
        forceRefresh: forceRefresh,
      ),
      AccountingRepository.fetchPaymentRegister(
        startDate: firstDay,
        endDate: lastDay,
        forceRefresh: forceRefresh,
      ),
    ]);
    return _PaymentsWorkspaceData(
      balances: results[0] as List<MonthlyTimesheetRow>,
      payments: results[1] as List<AccountingPaymentRegisterRow>,
    );
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  void changeMonth(int offset) {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month + offset,
        1,
      );
      future = load(forceRefresh: true);
    });
  }

  Future<void> addPayment() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => AddPaymentScreen(
          periodYear: selectedMonth.year,
          periodMonth: selectedMonth.month,
          periodTitle: accountingMonth(selectedMonth),
          initialObjectName: objectName,
        ),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  void openDetailedMode() {
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => PaymentsScreen(selectedObjectName: objectName),
      ),
    );
  }

  List<String> objectOptions(_PaymentsWorkspaceData data) {
    return <String>{
      ...data.balances
          .map((row) => row.employee.objectName.trim())
          .where((value) => value.isNotEmpty),
      ...data.payments
          .map((row) => row.objectName.trim())
          .where((value) => value.isNotEmpty),
    }.toList()
      ..sort();
  }

  bool matchesSearch(String values) {
    final query = searchController.text.trim().toLowerCase();
    return query.isEmpty || values.toLowerCase().contains(query);
  }

  List<MonthlyTimesheetRow> visibleBalances(_PaymentsWorkspaceData data) {
    final result = data.balances.where((row) {
      if (objectName != null && row.employee.objectName.trim() != objectName) {
        return false;
      }
      return matchesSearch(
        '${row.employee.name} ${row.employee.position} ${row.employee.objectName}',
      );
    }).toList();
    result.sort((a, b) => b.balance.compareTo(a.balance));
    return result;
  }

  List<AccountingPaymentRegisterRow> visiblePayments(
    _PaymentsWorkspaceData data,
  ) {
    return data.payments.where((row) {
      if (objectName != null && row.objectName.trim() != objectName) {
        return false;
      }
      if (receiptFilter == 'missing' && row.receiptCount > 0) return false;
      if (receiptFilter == 'confirmed' && row.receiptCount == 0) return false;
      return matchesSearch(
        '${row.employeeName} ${row.objectName} ${row.paymentType} ${row.comment}',
      );
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
      case 'cash':
        return 'Наличные';
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
          onPressed: openDetailedMode,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Детальный режим'),
        ),
        FilledButton.icon(
          onPressed: addPayment,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить выплату'),
        ),
      ],
    );
  }

  Widget filters(_PaymentsWorkspaceData data) {
    final objects = objectOptions(data);
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'Сотрудник, объект, тип выплаты или комментарий',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              initialValue: objects.contains(objectName) ? objectName : null,
              decoration: const InputDecoration(
                labelText: 'Объект',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все объекты'),
                ),
                ...objects.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => objectName = value),
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
              onChanged: (value) {
                setState(() => receiptFilter = value ?? 'all');
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget summary(_PaymentsWorkspaceData data) {
    final balances = visibleBalances(data);
    final payments = visiblePayments(data);
    final accrued = balances.fold<double>(0, (sum, row) => sum + row.accrued);
    final paid = balances.fold<double>(0, (sum, row) => sum + row.paid);
    final balance = accrued - paid;
    final operations = payments.fold<double>(0, (sum, row) => sum + row.amount);
    final missing = payments.where((row) => row.receiptCount == 0).length;

    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.calculate_outlined,
            label: 'Начислено',
            value: accountingMoney(accrued),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.payments_outlined,
            label: 'Выплачено',
            value: accountingMoney(paid),
            accent: specialistSuccess,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.account_balance_wallet_outlined,
            label: balance >= 0 ? 'К выплате' : 'Переплата',
            value: accountingMoney(balance.abs()),
            accent: balance >= 0 ? specialistWarning : specialistDanger,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.receipt_long_outlined,
            label: 'Операции',
            value: accountingMoney(operations),
            hint: '${payments.length} записей • без чека: $missing',
            accent: missing > 0 ? specialistDanger : specialistSuccess,
          ),
        ),
      ],
    );
  }

  Widget balancesTable(List<MonthlyTimesheetRow> rows) {
    return SpecialistDesktopTable(
      minWidth: 1160,
      columns: const [
        SpecialistTableColumn('Сотрудник', flex: 4),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Смены', flex: 1),
        SpecialistTableColumn('Ставка', flex: 2),
        SpecialistTableColumn('Начислено', flex: 2),
        SpecialistTableColumn('Выплачено', flex: 2),
        SpecialistTableColumn('Остаток', flex: 2),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              onTap: openDetailedMode,
              cells: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    specialistCellText(
                      row.employee.name,
                      weight: FontWeight.w900,
                    ),
                    specialistCellText(
                      row.employee.position,
                      color: specialistMuted,
                      weight: FontWeight.w600,
                      maxLines: 1,
                    ),
                  ],
                ),
                specialistCellText(
                  row.employee.objectName,
                  color: specialistMuted,
                ),
                specialistCellText(row.totalShifts.toStringAsFixed(1)),
                specialistCellText(
                  accountingMoney(row.employee.dailyRate.toDouble()),
                ),
                specialistCellText(accountingMoney(row.accrued)),
                specialistCellText(
                  accountingMoney(row.paid),
                  color: specialistSuccess,
                ),
                SpecialistStatusPill(
                  label: accountingMoney(row.balance.abs()),
                  color: row.balance > 0
                      ? specialistWarning
                      : row.balance < 0
                          ? specialistDanger
                          : specialistSuccess,
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget paymentsTable(List<AccountingPaymentRegisterRow> rows) {
    return SpecialistDesktopTable(
      minWidth: 1180,
      columns: const [
        SpecialistTableColumn('Дата', flex: 2),
        SpecialistTableColumn('Сотрудник', flex: 3),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Сумма', flex: 2),
        SpecialistTableColumn('Чек', flex: 2),
        SpecialistTableColumn('Комментарий', flex: 4),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              onTap: openDetailedMode,
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

  Widget sectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PaymentsWorkspaceData>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.payments_outlined,
              title: 'Загружаем выплаты',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить выплаты',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          final balances = visibleBalances(data);
          final payments = visiblePayments(data);
          children.add(filters(data));
          children.add(const SizedBox(height: 16));
          children.add(summary(data));
          children.add(const SizedBox(height: 20));
          children.add(
            sectionTitle(
              'Начисления по сотрудникам',
              'Смены, ставка, начислено, выплачено и текущий остаток',
            ),
          );
          if (balances.isEmpty) {
            children.add(
              const SpecialistMessageCard(
                icon: Icons.person_search_outlined,
                title: 'Сотрудники не найдены',
                description: 'Измените поиск или фильтр по объекту.',
              ),
            );
          } else {
            children.add(balancesTable(balances));
          }
          children.add(const SizedBox(height: 20));
          children.add(
            sectionTitle(
              'Реестр операций',
              'Все выплаты за выбранный месяц и статус подтверждающих файлов',
            ),
          );
          if (payments.isEmpty) {
            children.add(
              const SpecialistMessageCard(
                icon: Icons.receipt_long_outlined,
                title: 'Выплат за период нет',
                description: 'Добавьте выплату или измените выбранные фильтры.',
              ),
            );
          } else {
            children.add(paymentsTable(payments));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-payments',
          title: 'Выплаты и остатки',
          subtitle:
              'Полная финансовая таблица по сотрудникам и операциям компании',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}

class _PaymentsWorkspaceData {
  final List<MonthlyTimesheetRow> balances;
  final List<AccountingPaymentRegisterRow> payments;

  const _PaymentsWorkspaceData({
    required this.balances,
    required this.payments,
  });
}
