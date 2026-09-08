import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../navigation/app_page_route.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_today_details_screen.dart';
import 'accounting_widgets.dart';

class AccountingDashboardScreen extends StatefulWidget {
  // Эти параметры сохранены для совместимости с adaptive-обёрткой. На
  // мобильном «Сегодня» больше не использует общие переходы по вкладкам:
  // каждое нажатие открывает свой контекстный drill-down.
  const AccountingDashboardScreen({
    super.key,
    AppUserProfile? profile,
    VoidCallback? onOpenPeople,
    VoidCallback? onOpenExpenses,
    VoidCallback? onOpenDocuments,
    VoidCallback? onOpenControl,
  });

  @override
  State<AccountingDashboardScreen> createState() =>
      _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState extends State<AccountingDashboardScreen> {
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
      refresh(forceRefresh: false);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> refresh({bool forceRefresh = true}) async {
    final next = AccountingRepository.fetchDashboard(
      forceRefresh: forceRefresh,
    );
    setState(() => future = next);
    await next;
  }

  Future<void> openDetails(
    AccountingDashboardData data,
    AccountingTodayDetailsMode mode,
  ) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => AccountingTodayDetailsScreen(
          month: data.month,
          mode: mode,
        ),
      ),
    );
    if (mounted) await refresh(forceRefresh: true);
  }

  Future<void> openMissingReceipt(
    AccountingDashboardData data,
    AccountingMissingReceipt item,
  ) async {
    try {
      final rows = await AccountingRepository.fetchSettlementPaymentRegister(
        month: data.month,
      );
      AccountingPaymentRegisterRow? target;
      for (final row in rows) {
        if (row.paymentId == item.paymentId) {
          target = row;
          break;
        }
      }
      if (!mounted) return;
      if (target == null || target.employee == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть эту выплату')),
        );
        return;
      }
      await Navigator.of(context).push<bool>(
        AppPageRoute<bool>(
          builder: (_) => AccountingPaymentDetailScreen(row: target!),
        ),
      );
      if (mounted) await refresh(forceRefresh: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть выплату: $error')),
      );
    }
  }

  Widget summary(AccountingDashboardData data) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 30,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.22),
                      scheme.primary.withValues(alpha: 0.07),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                  size: 27,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Финансовая сводка',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      accountingMonth(data.month),
                      style: TextStyle(
                        color: accountingMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

  Widget receipts(AccountingDashboardData data) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Выплаты без чека',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
              if (data.missingReceiptCount > data.missingReceipts.length)
                TextButton(
                  onPressed: () => openDetails(
                    data,
                    AccountingTodayDetailsMode.missingReceipts,
                  ),
                  child: const Text('Все'),
                ),
            ],
          ),
          const SizedBox(height: 10),
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
              subtitle: Text(
                '${accountingDate(item.paymentDate)} · ${item.objectName}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    accountingMoney(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              onTap: () => openMissingReceipt(data, item),
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
                    const Text(
                      'Не удалось загрузить сводку',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            children: [
              summary(data),
              const SizedBox(height: 14),
              AccountingMetricCard(
                icon: Icons.groups_outlined,
                title: 'Сотрудников с остатком',
                value: data.employeesWithBalance.toString(),
                subtitle: 'Открыть конкретные расчёты',
                onTap: () => openDetails(
                  data,
                  AccountingTodayDetailsMode.balances,
                ),
              ),
              const SizedBox(height: 12),
              AccountingMetricCard(
                icon: Icons.payments_outlined,
                title: 'Выплат проведено',
                value: data.paymentCount.toString(),
                subtitle: 'Открыть выплаты за ${accountingMonth(data.month)}',
                onTap: () => openDetails(
                  data,
                  AccountingTodayDetailsMode.payments,
                ),
              ),
              const SizedBox(height: 12),
              AccountingMetricCard(
                icon: Icons.receipt_long_outlined,
                title: 'Выплат без чека',
                value: data.missingReceiptCount.toString(),
                subtitle: 'Открыть только проблемные выплаты',
                onTap: () => openDetails(
                  data,
                  AccountingTodayDetailsMode.missingReceipts,
                ),
              ),
              const SizedBox(height: 16),
              receipts(data),
            ],
          );
        },
      ),
    );
  }
}
