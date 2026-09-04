import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_repository.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_dashboard_screen.dart';
import 'accounting_widgets.dart';
import 'accounting_workspace_widgets.dart';

class AdaptiveAccountingDashboardScreen extends StatelessWidget {
  final AppUserProfile profile;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenReports;

  const AdaptiveAccountingDashboardScreen({
    super.key,
    required this.profile,
    required this.onOpenPayments,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return AccountingDashboardScreen(
            profile: profile,
            onOpenPayments: onOpenPayments,
            onOpenReports: onOpenReports,
          );
        }
        return _DesktopAccountingDashboardScreen(
          onOpenPayments: onOpenPayments,
          onOpenControl: onOpenReports,
        );
      },
    );
  }
}

class _DesktopAccountingDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenControl;

  const _DesktopAccountingDashboardScreen({
    required this.onOpenPayments,
    required this.onOpenControl,
  });

  @override
  State<_DesktopAccountingDashboardScreen> createState() =>
      _DesktopAccountingDashboardScreenState();
}

class _DesktopAccountingDashboardScreenState
    extends State<_DesktopAccountingDashboardScreen> {
  final workbench = AccountingWorkbenchRepository();
  late DateTime selectedMonth;
  late Future<_TodayBundle> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = DateTime(now.year, now.month, 1);
    future = load();
    subscription = AppDataSync.changes.listen((_) {
      if (mounted) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  DateTime get firstDay =>
      DateTime(selectedMonth.year, selectedMonth.month, 1);
  DateTime get lastDay =>
      DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

  Future<_TodayBundle> load({bool forceRefresh = false}) async {
    final result = await Future.wait<dynamic>([
      AccountingRepository.fetchDashboard(
        month: selectedMonth,
        forceRefresh: forceRefresh,
      ),
      workbench.fetchBankTransactions(from: firstDay, to: lastDay),
      workbench.fetchCalendarTasks(limit: 10),
      workbench.fetchDocuments(),
    ]);
    return _TodayBundle(
      finance: result[0] as AccountingDashboardData,
      bank: result[1] as List<AccountingBankTransaction>,
      tasks: result[2] as List<AccountingCalendarTask>,
      documents: result[3] as List<AccountingPrimaryDocument>,
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

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        IconButton.filledTonal(
          tooltip: 'Предыдущий месяц',
          onPressed: () => changeMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 160),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: specialistSoft,
            borderRadius: BorderRadius.circular(18),
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
        FilledButton.icon(
          onPressed: widget.onOpenPayments,
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Открыть операции'),
        ),
      ],
    );
  }

  Widget taskCard(List<AccountingCalendarTask> tasks) {
    return SpecialistDesktopSection(
      title: 'Ближайшие задачи',
      subtitle: 'Зарплата, налоги, отчётность и обязательные платежи',
      trailing: TextButton.icon(
        onPressed: widget.onOpenControl,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Контроль'),
      ),
      child: tasks.isEmpty
          ? const AccountingEmptyState(
              icon: Icons.event_available_outlined,
              title: 'Ближайших задач нет',
              description: 'Добавьте сроки в разделе «Контроль».',
            )
          : SpecialistDesktopTable(
              minWidth: 760,
              columns: const [
                SpecialistTableColumn('Срок', flex: 2),
                SpecialistTableColumn('Задача', flex: 6),
                SpecialistTableColumn('Тип', flex: 2),
              ],
              rows: tasks
                  .map(
                    (task) => SpecialistTableRowData(
                      onTap: widget.onOpenControl,
                      cells: [
                        specialistCellText(accountingDate(task.dueDate)),
                        specialistCellText(
                          task.title,
                          weight: FontWeight.w900,
                        ),
                        specialistCellText(_taskKind(task.kind)),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget balancesCard(AccountingDashboardData data) {
    return SpecialistDesktopSection(
      title: 'Крупные остатки сотрудникам',
      subtitle: 'Кому нужно выплатить в первую очередь',
      trailing: TextButton.icon(
        onPressed: widget.onOpenPayments,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Все выплаты'),
      ),
      child: data.largestBalances.isEmpty
          ? const AccountingEmptyState(
              icon: Icons.verified_outlined,
              title: 'Остатков к выплате нет',
              description: 'По текущему месяцу сотрудники рассчитаны.',
            )
          : SpecialistDesktopTable(
              minWidth: 760,
              columns: const [
                SpecialistTableColumn('Сотрудник', flex: 5),
                SpecialistTableColumn('Объект', flex: 3),
                SpecialistTableColumn('Смены', flex: 2),
                SpecialistTableColumn('Остаток', flex: 2),
              ],
              rows: data.largestBalances
                  .map(
                    (row) => SpecialistTableRowData(
                      onTap: widget.onOpenPayments,
                      cells: [
                        specialistCellText(
                          row.employee.name,
                          weight: FontWeight.w900,
                        ),
                        specialistCellText(row.employee.objectName),
                        specialistCellText(row.totalShifts.toStringAsFixed(1)),
                        AccountingStatusBadge(
                          label: accountingMoney(row.balance),
                          color: specialistWarning,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget documentAttentionCard(List<AccountingPrimaryDocument> documents) {
    final rows = documents
        .where((e) => e.status == 'draft' || e.status == 'attention')
        .take(6)
        .toList(growable: false);
    return SpecialistDesktopSection(
      title: 'Документы к обработке',
      subtitle: 'Черновики и первичка, требующая внимания',
      child: rows.isEmpty
          ? const AccountingEmptyState(
              icon: Icons.description_outlined,
              title: 'Документы обработаны',
              description: 'Нет первичных документов, требующих внимания.',
            )
          : SpecialistDesktopTable(
              minWidth: 760,
              columns: const [
                SpecialistTableColumn('Дата', flex: 2),
                SpecialistTableColumn('Контрагент', flex: 5),
                SpecialistTableColumn('Сумма', flex: 2),
                SpecialistTableColumn('Статус', flex: 2),
              ],
              rows: rows
                  .map(
                    (row) => SpecialistTableRowData(
                      cells: [
                        specialistCellText(accountingDate(row.date)),
                        specialistCellText(
                          row.counterparty,
                          weight: FontWeight.w900,
                        ),
                        specialistCellText(accountingMoney(row.amount)),
                        AccountingStatusBadge(
                          label: accountingDocStatusLabel(row.status),
                          color: accountingDocStatusColor(row.status),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TodayBundle>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.dashboard_outlined,
              title: 'Загружаем рабочий день бухгалтера',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить бухгалтерскую сводку',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          final incoming = data.bank
              .where((e) => e.direction == 'in')
              .fold<double>(0, (sum, e) => sum + e.amount);
          final outgoing = data.bank
              .where((e) => e.direction == 'out')
              .fold<double>(0, (sum, e) => sum + e.amount);

          children.add(
            Row(
              children: [
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.south_west_rounded,
                    label: 'Поступления по банку',
                    value: accountingMoney(incoming),
                    accent: specialistSuccess,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.north_east_rounded,
                    label: 'Списания по банку',
                    value: accountingMoney(outgoing),
                    accent: specialistDanger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'К выплате сотрудникам',
                    value: accountingMoney(data.finance.totalBalance.abs()),
                    accent: specialistWarning,
                    onTap: widget.onOpenPayments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Выплат без чека',
                    value: '${data.finance.missingReceiptCount}',
                    accent: data.finance.missingReceiptCount > 0
                        ? specialistDanger
                        : specialistSuccess,
                    onTap: widget.onOpenPayments,
                  ),
                ),
              ],
            ),
          );
          children.add(const SizedBox(height: 20));
          children.add(taskCard(data.tasks));
          children.add(const SizedBox(height: 20));
          children.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: balancesCard(data.finance)),
                const SizedBox(width: 20),
                Expanded(child: documentAttentionCard(data.documents)),
              ],
            ),
          );
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-dashboard',
          title: 'Сегодня',
          subtitle:
              'Деньги, выплаты, документы и обязательные задачи в одной сводке',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }

  String _taskKind(String kind) {
    return switch (kind) {
      'tax' => 'Налог',
      'report' => 'Отчётность',
      'salary' => 'Зарплата',
      'payment' => 'Платёж',
      _ => 'Другое',
    };
  }
}

class _TodayBundle {
  final AccountingDashboardData finance;
  final List<AccountingBankTransaction> bank;
  final List<AccountingCalendarTask> tasks;
  final List<AccountingPrimaryDocument> documents;

  const _TodayBundle({
    required this.finance,
    required this.bank,
    required this.tasks,
    required this.documents,
  });
}
