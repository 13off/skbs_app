import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../expenses/data/expense_repository.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_bank_import.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';
import 'accounting_workspace_widgets.dart';
import 'adaptive_accounting_payments_screen.dart';

class AdaptiveAccountingOperationsScreen extends StatefulWidget {
  const AdaptiveAccountingOperationsScreen({super.key});

  @override
  State<AdaptiveAccountingOperationsScreen> createState() =>
      _AdaptiveAccountingOperationsScreenState();
}

class _AdaptiveAccountingOperationsScreenState
    extends State<AdaptiveAccountingOperationsScreen> {
  final workbench = AccountingWorkbenchRepository();
  final expenses = ExpenseRepository();
  String view = 'bank';
  late DateTime month;
  late Future<_OperationsData> future;
  bool importingBank = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    month = DateTime(now.year, now.month, 1);
    future = load();
  }

  DateTime get firstDay => DateTime(month.year, month.month, 1);
  DateTime get lastDay => DateTime(month.year, month.month + 1, 0);

  Future<_OperationsData> load() async {
    final result = await Future.wait<dynamic>([
      workbench.fetchBankTransactions(from: firstDay, to: lastDay),
      workbench.fetchBankAccounts(),
      expenses.fetchSnapshot(from: firstDay, to: lastDay),
    ]);
    return _OperationsData(
      bank: result[0] as List<AccountingBankTransaction>,
      bankAccounts: result[1] as List<AccountingBankAccount>,
      expenses: result[2] as ExpensesSnapshot,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void changeMonth(int offset) {
    setState(() {
      month = DateTime(month.year, month.month + offset, 1);
      future = load();
    });
  }

  Future<void> addBankTransaction() async {
    final result = await showDialog<_BankDraft>(
      context: context,
      builder: (_) => const _AddBankTransactionDialog(),
    );
    if (result == null) return;
    await workbench.createBankTransaction(
      date: result.date,
      direction: result.direction,
      amount: result.amount,
      counterparty: result.counterparty,
      purpose: result.purpose,
    );
    await refresh();
  }

  Future<void> setCurrentBalance(_OperationsData? data) async {
    final current = data?.bankAccounts.fold<double>(
          0,
          (sum, account) => sum + account.balance,
        ) ??
        0;
    final controller = TextEditingController(
      text: current == 0 ? '' : current.toStringAsFixed(2),
    );
    final balance = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Остаток на расчётном счёте'),
        content: SizedBox(
          width: 430,
          child: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Текущий остаток',
              prefixIcon: Icon(Icons.account_balance_outlined),
              suffixText: '₽',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(
                controller.text.replaceAll(' ', '').replaceAll(',', '.'),
              );
              if (parsed == null || parsed < 0) return;
              Navigator.pop(context, parsed);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (balance == null) return;
    await workbench.setBankBalance(balance: balance);
    await refresh();
  }

  Future<void> importBankStatement() async {
    if (importingBank) return;
    const csvType = XTypeGroup(label: 'CSV', extensions: ['csv']);
    final file = await openFile(acceptedTypeGroups: const [csvType]);
    if (file == null) return;
    setState(() => importingBank = true);
    try {
      final bytes = await file.readAsBytes();
      final parsed = AccountingBankImport.parse(bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт банковской выписки'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Распознано операций: ${parsed.rows.length}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Новые контрагенты из выписки будут автоматически добавлены в справочник.',
                ),
                if (parsed.warnings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Предупреждений: ${parsed.warnings.length}',
                    style: TextStyle(
                      color: specialistWarning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...parsed.warnings.take(5).map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $warning'),
                        ),
                      ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Импортировать'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final count = await workbench.importBankTransactions(parsed.rows);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Импортировано банковских операций: $count')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось импортировать выписку: $error')),
      );
    } finally {
      if (mounted) setState(() => importingBank = false);
    }
  }

  Future<void> addExpense() async {
    final result = await showDialog<_ExpenseDraft>(
      context: context,
      builder: (_) => const _AddExpenseDialog(),
    );
    if (result == null) return;
    await expenses.createExpense(
      name: result.name,
      amount: result.amount,
      date: result.date,
      counterpartyName: result.counterparty,
      comment: result.comment,
    );
    await refresh();
  }

  Widget actions(_OperationsData? data) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
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
            accountingMonth(month),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Следующий месяц',
          onPressed: () => changeMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        if (view == 'bank') ...[
          OutlinedButton.icon(
            onPressed: importingBank ? null : importBankStatement,
            icon: importingBank
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
            label: const Text('Импорт выписки'),
          ),
          OutlinedButton.icon(
            onPressed: () => setCurrentBalance(data),
            icon: const Icon(Icons.account_balance_outlined),
            label: const Text('Остаток на счёте'),
          ),
          FilledButton.icon(
            onPressed: addBankTransaction,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить операцию'),
          ),
        ],
        if (view == 'expenses')
          FilledButton.icon(
            onPressed: addExpense,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить расход'),
          ),
      ],
    );
  }

  Widget bankView(_OperationsData data) {
    final rows = data.bank;
    final incoming = rows
        .where((e) => e.direction == 'in')
        .fold<double>(0, (sum, e) => sum + e.amount);
    final outgoing = rows
        .where((e) => e.direction == 'out')
        .fold<double>(0, (sum, e) => sum + e.amount);
    final currentBalance = data.bankAccounts.fold<double>(
      0,
      (sum, account) => sum + account.balance,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'На счетах сейчас',
                value: accountingMoney(currentBalance),
                accent: specialistText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.south_west_rounded,
                label: 'Поступления',
                value: accountingMoney(incoming),
                accent: specialistSuccess,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.north_east_rounded,
                label: 'Списания',
                value: accountingMoney(outgoing),
                accent: specialistDanger,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.swap_vert_rounded,
                label: 'Сальдо за период',
                value: accountingMoney(incoming - outgoing),
                accent: incoming - outgoing >= 0
                    ? specialistSuccess
                    : specialistWarning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          AccountingEmptyState(
            icon: Icons.account_balance_outlined,
            title: 'Банковских операций за период нет',
            description:
                'Загрузите CSV-выписку из банка или добавьте операцию вручную.',
            actionLabel: 'Импортировать выписку',
            onAction: () async => importBankStatement(),
          )
        else
          SpecialistDesktopTable(
            minWidth: 1050,
            columns: const [
              SpecialistTableColumn('Дата', flex: 2),
              SpecialistTableColumn('Тип', flex: 2),
              SpecialistTableColumn('Контрагент', flex: 4),
              SpecialistTableColumn('Назначение', flex: 6),
              SpecialistTableColumn('Сумма', flex: 2),
              SpecialistTableColumn('Статус', flex: 2),
            ],
            rows: rows
                .map(
                  (row) => SpecialistTableRowData(
                    cells: [
                      specialistCellText(accountingDate(row.date)),
                      specialistCellText(
                        row.direction == 'in' ? 'Поступление' : 'Списание',
                        color: row.direction == 'in'
                            ? specialistSuccess
                            : specialistDanger,
                        weight: FontWeight.w800,
                      ),
                      specialistCellText(
                        row.counterparty.isEmpty ? '—' : row.counterparty,
                      ),
                      specialistCellText(
                        row.purpose.isEmpty ? '—' : row.purpose,
                        color: specialistMuted,
                      ),
                      specialistCellText(
                        accountingMoney(row.amount),
                        weight: FontWeight.w900,
                      ),
                      AccountingStatusBadge(
                        label: switch (row.status) {
                          'matched' => 'Распознано',
                          'attention' => 'Проверить',
                          _ => 'Новая',
                        },
                        color: switch (row.status) {
                          'matched' => specialistSuccess,
                          'attention' => specialistDanger,
                          _ => specialistWarning,
                        },
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget expensesView(ExpensesSnapshot snapshot) {
    final rows = snapshot.rows;
    final total = rows.fold<double>(0, (sum, e) => sum + e.amount);
    final withFiles = rows.where((e) => e.attachments.isNotEmpty).length;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.receipt_long_outlined,
                label: 'Расходы за период',
                value: accountingMoney(total),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.format_list_numbered_rounded,
                label: 'Операций',
                value: '${rows.length}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.attach_file_rounded,
                label: 'С подтверждением',
                value: '$withFiles',
                accent: withFiles == rows.length
                    ? specialistSuccess
                    : specialistWarning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const AccountingEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Расходов за период нет',
            description: 'Добавьте расход или выберите другой месяц.',
          )
        else
          SpecialistDesktopTable(
            minWidth: 1100,
            columns: const [
              SpecialistTableColumn('Дата', flex: 2),
              SpecialistTableColumn('Расход', flex: 4),
              SpecialistTableColumn('Контрагент', flex: 3),
              SpecialistTableColumn('Объект', flex: 3),
              SpecialistTableColumn('Статья', flex: 3),
              SpecialistTableColumn('Сумма', flex: 2),
              SpecialistTableColumn('Файлы', flex: 2),
            ],
            rows: rows
                .map(
                  (row) => SpecialistTableRowData(
                    cells: [
                      specialistCellText(accountingDate(row.date)),
                      specialistCellText(row.name, weight: FontWeight.w900),
                      specialistCellText(row.counterpartyName),
                      specialistCellText(row.objectName ?? '—'),
                      specialistCellText(row.categoryName),
                      specialistCellText(
                        accountingMoney(row.amount),
                        weight: FontWeight.w900,
                      ),
                      AccountingStatusBadge(
                        label: row.attachments.isEmpty
                            ? 'Нет файла'
                            : 'Файлов: ${row.attachments.length}',
                        color: row.attachments.isEmpty
                            ? specialistWarning
                            : specialistSuccess,
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (view == 'payments') {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: AccountingSectionSwitcher(
              selected: view,
              items: const [
                ('bank', 'Банк', Icons.account_balance_outlined),
                ('expenses', 'Расходы', Icons.receipt_long_outlined),
                ('payments', 'Выплаты', Icons.payments_outlined),
              ],
              onChanged: (value) => setState(() => view = value),
            ),
          ),
          const Expanded(child: AdaptiveAccountingPaymentsScreen()),
        ],
      );
    }

    return FutureBuilder<_OperationsData>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final children = <Widget>[
          AccountingSectionSwitcher(
            selected: view,
            items: const [
              ('bank', 'Банк', Icons.account_balance_outlined),
              ('expenses', 'Расходы', Icons.receipt_long_outlined),
              ('payments', 'Выплаты', Icons.payments_outlined),
            ],
            onChanged: (value) => setState(() => view = value),
          ),
          const SizedBox(height: 16),
        ];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Загружаем операции',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить операции',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else if (data != null) {
          children.add(
            view == 'bank' ? bankView(data) : expensesView(data.expenses),
          );
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-operations',
          title: 'Операции',
          subtitle: 'Банк, расходы и выплаты в одном рабочем разделе',
          trailing: actions(data),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}

class _OperationsData {
  final List<AccountingBankTransaction> bank;
  final List<AccountingBankAccount> bankAccounts;
  final ExpensesSnapshot expenses;

  const _OperationsData({
    required this.bank,
    required this.bankAccounts,
    required this.expenses,
  });
}

class _BankDraft {
  final DateTime date;
  final String direction;
  final double amount;
  final String counterparty;
  final String purpose;

  const _BankDraft({
    required this.date,
    required this.direction,
    required this.amount,
    required this.counterparty,
    required this.purpose,
  });
}

class _AddBankTransactionDialog extends StatefulWidget {
  const _AddBankTransactionDialog();

  @override
  State<_AddBankTransactionDialog> createState() =>
      _AddBankTransactionDialogState();
}

class _AddBankTransactionDialogState extends State<_AddBankTransactionDialog> {
  String direction = 'out';
  final amount = TextEditingController();
  final counterparty = TextEditingController();
  final purpose = TextEditingController();

  @override
  void dispose() {
    amount.dispose();
    counterparty.dispose();
    purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Банковская операция'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: direction,
              decoration: const InputDecoration(labelText: 'Тип операции'),
              items: const [
                DropdownMenuItem(value: 'in', child: Text('Поступление')),
                DropdownMenuItem(value: 'out', child: Text('Списание')),
              ],
              onChanged: (value) =>
                  setState(() => direction = value ?? 'out'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: counterparty,
              decoration: const InputDecoration(labelText: 'Контрагент'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: purpose,
              decoration: const InputDecoration(
                labelText: 'Назначение платежа',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
            if (parsed == null || parsed <= 0) return;
            Navigator.pop(
              context,
              _BankDraft(
                date: DateTime.now(),
                direction: direction,
                amount: parsed,
                counterparty: counterparty.text.trim(),
                purpose: purpose.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ExpenseDraft {
  final DateTime date;
  final String name;
  final double amount;
  final String counterparty;
  final String comment;

  const _ExpenseDraft({
    required this.date,
    required this.name,
    required this.amount,
    required this.counterparty,
    required this.comment,
  });
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog();

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final name = TextEditingController();
  final amount = TextEditingController();
  final counterparty = TextEditingController();
  final comment = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    counterparty.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый расход'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Наименование'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: counterparty,
              decoration: const InputDecoration(labelText: 'Контрагент'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comment,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = double.tryParse(amount.text.replaceAll(',', '.'));
            if (parsed == null || parsed <= 0 || name.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _ExpenseDraft(
                date: DateTime.now(),
                name: name.text.trim(),
                amount: parsed,
                counterparty: counterparty.text.trim(),
                comment: comment.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
