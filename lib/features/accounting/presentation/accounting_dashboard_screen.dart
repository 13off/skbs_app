import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/add_payment_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_widgets.dart';

class AccountingDashboardScreen extends StatefulWidget {
  final AppUserProfile profile;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenReports;

  const AccountingDashboardScreen({
    super.key,
    required this.profile,
    required this.onOpenPayments,
    required this.onOpenReports,
  });

  @override
  State<AccountingDashboardScreen> createState() =>
      _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState
    extends State<AccountingDashboardScreen> {
  late Future<AccountingDashboardData> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = AccountingRepository.fetchDashboard();
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

  Future<void> refresh() async {
    final next = AccountingRepository.fetchDashboard(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Future<void> addPayment() async {
    final now = DateTime.now();
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => AddPaymentScreen(
          periodYear: now.year,
          periodMonth: now.month,
          periodTitle: accountingMonth(now),
        ),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  Widget summary(AccountingDashboardData data) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accountingSoft,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Финансовая сводка',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      accountingMonth(data.month),
                      style: const TextStyle(
                        color: accountingMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AccountingMoneyBlock(
                  title: 'Начислено',
                  value: accountingMoney(data.totalAccrued),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AccountingMoneyBlock(
                  title: 'Выплачено',
                  value: accountingMoney(data.totalPaid),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AccountingMoneyBlock(
            title: data.totalBalance >= 0 ? 'К выплате' : 'Переплата',
            value: accountingMoney(data.totalBalance.abs()),
            prominent: true,
          ),
        ],
      ),
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
                child: const Text('Все выплаты'),
              ),
            ],
          ),
          if (data.largestBalances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('Задолженностей за период нет')),
            ),
          ...data.largestBalances.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: accountingSoft,
                child: Icon(Icons.person_outline, color: accountingText),
              ),
              title: Text(
                row.employee.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(row.employee.objectName),
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
          const Text(
            'Выплаты без чека',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Проверьте подтверждающие файлы',
            style: TextStyle(color: accountingMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (data.missingReceipts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: Text('Все выплаты подтверждены')),
            ),
          ...data.missingReceipts.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(
                item.employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${accountingDate(item.paymentDate)} · ${item.objectName}'),
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
    return AppPage(
      title: 'Сегодня',
      subtitle: 'Начисления, выплаты, остатки и подтверждающие документы',
      headerTrailing: const NotificationBell(selectedObjectName: null),
      child: FutureBuilder<AccountingDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumWorkCard(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      'Не удалось загрузить сводку: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: refresh, child: const Text('Повторить')),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            children: [
              summary(data),
              const SizedBox(height: 12),
              AccountingMetricCard(
                icon: Icons.groups_outlined,
                title: 'Сотрудников с остатком',
                value: data.employeesWithBalance.toString(),
                subtitle: 'Всего в расчёте: ${data.employeeCount}',
                onTap: widget.onOpenPayments,
              ),
              const SizedBox(height: 10),
              AccountingMetricCard(
                icon: Icons.payments_outlined,
                title: 'Выплат проведено',
                value: data.paymentCount.toString(),
                subtitle: accountingMonth(data.month),
                onTap: widget.onOpenPayments,
              ),
              const SizedBox(height: 10),
              AccountingMetricCard(
                icon: Icons.receipt_long_outlined,
                title: 'Выплат без чека',
                value: data.missingReceiptCount.toString(),
                subtitle: 'Требуют подтверждающего файла',
                onTap: widget.onOpenPayments,
              ),
              const SizedBox(height: 14),
              PremiumActionButton(
                label: 'Добавить выплату',
                icon: Icons.add_card_rounded,
                onPressed: addPayment,
              ),
              const SizedBox(height: 10),
              PremiumActionButton(
                label: 'Открыть отчёты',
                icon: Icons.summarize_outlined,
                onPressed: widget.onOpenReports,
              ),
              const SizedBox(height: 14),
              balances(data),
              const SizedBox(height: 14),
              receipts(data),
            ],
          );
        },
      ),
    );
  }
}
