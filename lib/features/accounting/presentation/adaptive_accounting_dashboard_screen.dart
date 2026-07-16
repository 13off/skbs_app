import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/add_payment_screen.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_dashboard_screen.dart';
import 'accounting_widgets.dart';

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
          onOpenReports: onOpenReports,
        );
      },
    );
  }
}

class _DesktopAccountingDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenReports;

  const _DesktopAccountingDashboardScreen({
    required this.onOpenPayments,
    required this.onOpenReports,
  });

  @override
  State<_DesktopAccountingDashboardScreen> createState() =>
      _DesktopAccountingDashboardScreenState();
}

class _DesktopAccountingDashboardScreenState
    extends State<_DesktopAccountingDashboardScreen> {
  late DateTime selectedMonth;
  late Future<AccountingDashboardData> future;
  StreamSubscription<AppDataChange>? subscription;

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
    super.dispose();
  }

  Future<AccountingDashboardData> load({bool forceRefresh = false}) {
    return AccountingRepository.fetchDashboard(
      month: selectedMonth,
      forceRefresh: forceRefresh,
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
        ),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        const NotificationBell(selectedObjectName: null),
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
          onPressed: widget.onOpenReports,
          icon: const Icon(Icons.summarize_outlined),
          label: const Text('Отчёты'),
        ),
        FilledButton.icon(
          onPressed: addPayment,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить выплату'),
        ),
      ],
    );
  }

  Widget balances(AccountingDashboardData data) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Крупные остатки',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenPayments,
                child: const Text('Все сотрудники'),
              ),
            ],
          ),
          const Text(
            'Сотрудники с наибольшей суммой к выплате',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (data.largestBalances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Остатков к выплате нет')),
            ),
          ...data.largestBalances.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: specialistSoft,
                child: Icon(Icons.person_outline, color: specialistText),
              ),
              title: Text(
                row.employee.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${row.employee.objectName} • ${row.totalShifts.toStringAsFixed(1)} смен',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                accountingMoney(row.balance),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onTap: widget.onOpenPayments,
            ),
          ),
        ],
      ),
    );
  }

  Widget receipts(AccountingDashboardData data) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Выплаты без чека',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenPayments,
                child: const Text('Открыть выплаты'),
              ),
            ],
          ),
          const Text(
            'Операции без подтверждающего файла',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (data.missingReceipts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Все выплаты подтверждены')),
            ),
          ...data.missingReceipts.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: specialistWarning.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: specialistWarning,
                ),
              ),
              title: Text(
                item.employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${accountingDate(item.paymentDate)} • ${item.objectName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                accountingMoney(item.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onTap: widget.onOpenPayments,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AccountingDashboardData>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Загружаем финансовую сводку',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить финансовую сводку',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          children.addAll([
            Row(
              children: [
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.calculate_outlined,
                    label: 'Начислено',
                    value: accountingMoney(data.totalAccrued),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.payments_outlined,
                    label: 'Выплачено',
                    value: accountingMoney(data.totalPaid),
                    accent: specialistSuccess,
                    onTap: widget.onOpenPayments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.account_balance_wallet_outlined,
                    label: data.totalBalance >= 0 ? 'К выплате' : 'Переплата',
                    value: accountingMoney(data.totalBalance.abs()),
                    accent: data.totalBalance >= 0
                        ? specialistWarning
                        : specialistDanger,
                    onTap: widget.onOpenPayments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Без чека',
                    value: '${data.missingReceiptCount}',
                    hint: '${data.paymentCount} операций за месяц',
                    accent: data.missingReceiptCount > 0
                        ? specialistDanger
                        : specialistSuccess,
                    onTap: widget.onOpenPayments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: balances(data)),
                const SizedBox(width: 18),
                Expanded(child: receipts(data)),
              ],
            ),
          ]);
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-dashboard',
          title: 'Финансовый контроль',
          subtitle:
              'Начисления, выплаты, остатки и подтверждающие документы',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}
