import 'dart:async';

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
import '../../../navigation/app_page_route.dart';

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
        );
      },
    );
  }
}

class _DesktopAccountingDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenPayments;

  const _DesktopAccountingDashboardScreen({required this.onOpenPayments});

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
      AppPageRoute<bool>(
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
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const NotificationBell(selectedObjectName: null),
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
          onPressed: addPayment,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить выплату'),
        ),
      ],
    );
  }

  Widget balances(AccountingDashboardData data) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Крупные остатки',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (data.largestBalances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Остатков к выплате нет')),
            ),
          ...data.largestBalances.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
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
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выплаты без чека',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          if (data.missingReceipts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Все выплаты подтверждены')),
            ),
          ...data.missingReceipts.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: specialistWarning.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
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
                const SizedBox(width: 14),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.payments_outlined,
                    label: 'Выплачено',
                    value: accountingMoney(data.totalPaid),
                    accent: specialistSuccess,
                    onTap: widget.onOpenPayments,
                  ),
                ),
                const SizedBox(width: 14),
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
                const SizedBox(width: 14),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.receipt_long_outlined,
                    label: 'Без чека',
                    value: '${data.missingReceiptCount}',
                    accent: data.missingReceiptCount > 0
                        ? specialistDanger
                        : specialistSuccess,
                    onTap: widget.onOpenPayments,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: balances(data)),
                const SizedBox(width: 20),
                Expanded(child: receipts(data)),
              ],
            ),
          ]);
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-dashboard',
          title: 'Финансовый контроль',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}
