import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../navigation/app_page_route.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';

enum AccountingBankDetailsMode { accounts, incoming, outgoing }

class AccountingBankDetailsScreen extends StatefulWidget {
  final DateTime month;
  final AccountingBankDetailsMode mode;

  const AccountingBankDetailsScreen({
    super.key,
    required this.month,
    required this.mode,
  });

  @override
  State<AccountingBankDetailsScreen> createState() =>
      _AccountingBankDetailsScreenState();
}

class _AccountingBankDetailsScreenState
    extends State<AccountingBankDetailsScreen> {
  final repository = AccountingWorkbenchRepository();
  late Future<_BankDetailsData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_BankDetailsData> load() async {
    if (widget.mode == AccountingBankDetailsMode.accounts) {
      return _BankDetailsData(accounts: await repository.fetchBankAccounts());
    }
    final start = DateTime(widget.month.year, widget.month.month, 1);
    final end = DateTime(widget.month.year, widget.month.month + 1, 0);
    final direction = widget.mode == AccountingBankDetailsMode.incoming
        ? 'in'
        : 'out';
    final rows = await repository.fetchBankTransactions(from: start, to: end);
    return _BankDetailsData(
      transactions: rows
          .where((row) => row.direction == direction)
          .toList(growable: false),
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String get title => switch (widget.mode) {
    AccountingBankDetailsMode.accounts => 'Счета и остатки',
    AccountingBankDetailsMode.incoming => 'Поступления по банку',
    AccountingBankDetailsMode.outgoing => 'Списания по банку',
  };

  String get subtitle => switch (widget.mode) {
    AccountingBankDetailsMode.accounts =>
      'Нажмите на счёт — откроется его текущий остаток и дата обновления',
    AccountingBankDetailsMode.incoming =>
      'Поступления за ${accountingMonth(widget.month)}. Нажмите на строку для деталей операции',
    AccountingBankDetailsMode.outgoing =>
      'Списания за ${accountingMonth(widget.month)}. Нажмите на строку для деталей операции',
  };

  Future<void> openTransaction(AccountingBankTransaction row) {
    return Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => AccountingBankTransactionDetailScreen(transaction: row),
      ),
    );
  }

  Future<void> openAccount(AccountingBankAccount row) {
    return Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => AccountingBankAccountDetailScreen(account: row),
      ),
    );
  }

  Widget transactionCard(AccountingBankTransaction row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => openTransaction(row),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.mode == AccountingBankDetailsMode.incoming
                    ? AppAdaptivePalette.success.withValues(alpha: 0.12)
                    : AppAdaptivePalette.danger.withValues(alpha: 0.12),
                child: Icon(
                  widget.mode == AccountingBankDetailsMode.incoming
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.counterparty.trim().isEmpty
                          ? 'Контрагент не указан'
                          : row.counterparty,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${accountingDate(row.date)} · ${row.purpose.trim().isEmpty ? 'Без назначения' : row.purpose}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                accountingMoney(row.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget accountCard(AccountingBankAccount row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => openAccount(row),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.account_balance_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Обновлено ${accountingDate(row.updatedAt)}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                accountingMoney(row.balance),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: FutureBuilder<_BankDetailsData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Не удалось загрузить данные: ${snapshot.error}'),
                ),
              );
            }
            final data = snapshot.data!;
            final rows = data.transactions;
            final accounts = data.accounts;
            final total = rows.fold<double>(0, (sum, row) => sum + row.amount);
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (widget.mode != AccountingBankDetailsMode.accounts)
                    PremiumWorkCard(
                      radius: 22,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Операций: ${rows.length}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Text(
                            accountingMoney(total),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.mode != AccountingBankDetailsMode.accounts)
                    const SizedBox(height: 14),
                  if (widget.mode == AccountingBankDetailsMode.accounts &&
                      accounts.isEmpty)
                    const PremiumWorkCard(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Банковские счета не найдены')),
                      ),
                    )
                  else if (widget.mode == AccountingBankDetailsMode.accounts)
                    ...accounts.map(accountCard)
                  else if (rows.isEmpty)
                    const PremiumWorkCard(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Операций за период нет')),
                      ),
                    )
                  else
                    ...rows.map(transactionCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AccountingBankTransactionDetailScreen extends StatelessWidget {
  final AccountingBankTransaction transaction;

  const AccountingBankTransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final incoming = transaction.direction == 'in';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(incoming ? 'Банковское поступление' : 'Банковское списание'),
      ),
      body: PremiumWorkBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow('Дата', accountingDate(transaction.date)),
                  _DetailRow('Сумма', accountingMoney(transaction.amount)),
                  _DetailRow(
                    'Контрагент',
                    transaction.counterparty.trim().isEmpty
                        ? 'Не указан'
                        : transaction.counterparty,
                  ),
                  _DetailRow(
                    'Назначение',
                    transaction.purpose.trim().isEmpty
                        ? 'Не указано'
                        : transaction.purpose,
                  ),
                  _DetailRow('Статус', _statusLabel(transaction.status)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'matched' => 'Сопоставлено',
    'attention' => 'Требует внимания',
    'new' => 'Новое',
    _ => status,
  };
}

class AccountingBankAccountDetailScreen extends StatelessWidget {
  final AccountingBankAccount account;

  const AccountingBankAccountDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(leading: const BackButton(), title: const Text('Счёт')),
      body: PremiumWorkBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _DetailRow('Текущий остаток', accountingMoney(account.balance)),
                  _DetailRow(
                    'Баланс обновлён',
                    accountingDate(account.updatedAt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _BankDetailsData {
  final List<AccountingBankTransaction> transactions;
  final List<AccountingBankAccount> accounts;

  const _BankDetailsData({
    this.transactions = const [],
    this.accounts = const [],
  });
}
