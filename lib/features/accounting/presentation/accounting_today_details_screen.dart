import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/payment_receipt_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../models/monthly_timesheet_row.dart';
import '../../../navigation/app_page_route.dart';
import '../../../screens/add_payment_screen.dart';
import '../../../screens/payment_history_screen.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_repository.dart';
import 'accounting_widgets.dart';

/// Контекстные переходы с бухгалтерского экрана «Сегодня».
/// Это не отдельный раздел: каждый переход сохраняет смысл нажатия.
enum AccountingTodayDetailsMode { balances, payments, missingReceipts }

class AccountingTodayDetailsScreen extends StatefulWidget {
  final DateTime month;
  final AccountingTodayDetailsMode mode;

  const AccountingTodayDetailsScreen({
    super.key,
    required this.month,
    required this.mode,
  });

  @override
  State<AccountingTodayDetailsScreen> createState() =>
      _AccountingTodayDetailsScreenState();
}

class _AccountingTodayDetailsScreenState
    extends State<AccountingTodayDetailsScreen> {
  late Future<_TodayDetailsData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_TodayDetailsData> load({bool forceRefresh = false}) async {
    if (widget.mode == AccountingTodayDetailsMode.balances) {
      final rows = await AccountingRepository.fetchBalanceRows(
        month: widget.month,
        forceRefresh: forceRefresh,
      );
      final balances = rows.where((row) => row.balance > 0.009).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));
      return _TodayDetailsData(balances: balances);
    }

    final payments = await AccountingRepository.fetchSettlementPaymentRegister(
      month: widget.month,
      forceRefresh: forceRefresh,
    );
    return _TodayDetailsData(
      payments: widget.mode == AccountingTodayDetailsMode.missingReceipts
          ? payments.where((row) => row.receiptCount == 0).toList()
          : payments,
    );
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  String get title => switch (widget.mode) {
    AccountingTodayDetailsMode.balances => 'Кому осталось выплатить',
    AccountingTodayDetailsMode.payments => 'Выплаты за период',
    AccountingTodayDetailsMode.missingReceipts => 'Выплаты без чека',
  };

  String get subtitle => switch (widget.mode) {
    AccountingTodayDetailsMode.balances =>
      'Нажмите на сотрудника — откроется его расчёт за ${accountingMonth(widget.month)}',
    AccountingTodayDetailsMode.payments =>
      'Все выплаты, отнесённые к ${accountingMonth(widget.month)}',
    AccountingTodayDetailsMode.missingReceipts =>
      'Нажмите на выплату — откроется именно она, чек можно приложить сразу',
  };

  Future<void> openSettlement(MonthlyTimesheetRow row) async {
    await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        builder: (_) => AccountingEmployeeSettlementScreen(
          month: widget.month,
          row: row,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> openPayment(AccountingPaymentRegisterRow row) async {
    if (row.employee == null || row.employeeId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить сотрудника выплаты')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => AccountingPaymentDetailScreen(row: row),
      ),
    );
    if (mounted) await refresh();
  }

  Widget balanceCard(MonthlyTimesheetRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => openSettlement(row),
        child: PremiumWorkCard(
          padding: const EdgeInsets.all(16),
          radius: 23,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppAdaptivePalette.accentSoft,
                child: const Icon(Icons.person_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employee.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${row.employee.position} • ${row.employee.objectName}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Начислено ${accountingMoney(row.accrued)} · выплачено ${accountingMoney(row.paid)}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    accountingMoney(row.balance),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'остаток',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget paymentCard(AccountingPaymentRegisterRow row) {
    final missingReceipt = row.receiptCount == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(23),
        onTap: () => openPayment(row),
        child: PremiumWorkCard(
          padding: const EdgeInsets.all(16),
          radius: 23,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: missingReceipt
                    ? AppAdaptivePalette.danger.withValues(alpha: 0.12)
                    : AppAdaptivePalette.accentSoft,
                child: Icon(
                  missingReceipt
                      ? Icons.receipt_long_outlined
                      : Icons.payments_outlined,
                  color: missingReceipt
                      ? AppAdaptivePalette.danger
                      : AppAdaptivePalette.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.employeeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${accountingDate(row.paymentDate)} • ${row.objectName.isEmpty ? 'Без объекта' : row.objectName}',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      missingReceipt
                          ? 'Нет подтверждающего чека'
                          : 'Чеков: ${row.receiptCount}',
                      style: TextStyle(
                        color: missingReceipt
                            ? AppAdaptivePalette.danger
                            : AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                accountingMoney(row.amount),
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
        child: FutureBuilder<_TodayDetailsData>(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'Не удалось загрузить данные\n${snapshot.error}',
                        textAlign: TextAlign.center,
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
            final empty = widget.mode == AccountingTodayDetailsMode.balances
                ? data.balances.isEmpty
                : data.payments.isEmpty;
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
                  const SizedBox(height: 16),
                  if (empty)
                    PremiumWorkCard(
                      padding: const EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          widget.mode == AccountingTodayDetailsMode.balances
                              ? 'Остатков к выплате нет'
                              : widget.mode ==
                                    AccountingTodayDetailsMode.missingReceipts
                              ? 'Все выплаты подтверждены чеками'
                              : 'Выплат за период нет',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                  else if (widget.mode == AccountingTodayDetailsMode.balances)
                    ...data.balances.map(balanceCard)
                  else
                    ...data.payments.map(paymentCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class AccountingEmployeeSettlementScreen extends StatelessWidget {
  final DateTime month;
  final MonthlyTimesheetRow row;

  const AccountingEmployeeSettlementScreen({
    super.key,
    required this.month,
    required this.row,
  });

  Future<void> openHistory(BuildContext context) async {
    final employeeId = row.employee.id?.trim() ?? '';
    if (employeeId.isEmpty) return;
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => PaymentHistoryScreen(
          employee: row.employee,
          employeeIds: [employeeId],
        ),
      ),
    );
  }

  Future<void> addPayment(BuildContext context) async {
    final employeeId = row.employee.id?.trim() ?? '';
    if (employeeId.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        builder: (_) => AddPaymentScreen(
          periodYear: month.year,
          periodMonth: month.month,
          periodTitle: accountingMonth(month),
          initialEmployeeId: employeeId,
          initialObjectName: row.employee.objectName,
        ),
      ),
    );
    if (changed == true && context.mounted) Navigator.of(context).pop(true);
  }

  Widget moneyLine(String title, num value, {bool prominent = false}) {
    return _DetailLine(
      title: title,
      value: accountingMoney(value.toDouble()),
      prominent: prominent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Расчёт сотрудника'),
      ),
      body: PremiumWorkBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            PremiumWorkCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.employee.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${row.employee.position} • ${row.employee.objectName}',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Расчётный период: ${accountingMonth(month)}',
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumWorkCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  moneyLine('Ставка', row.employee.monthlySalary),
                  const SizedBox(height: 10),
                  _DetailLine(
                    title: 'Учтено смен',
                    value: row.totalShifts.toStringAsFixed(1),
                  ),
                  const SizedBox(height: 10),
                  moneyLine('Начислено', row.accrued),
                  const SizedBox(height: 10),
                  moneyLine('Выплачено', row.paid),
                  const SizedBox(height: 10),
                  moneyLine('Осталось выплатить', row.balance, prominent: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => addPayment(context),
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('Добавить выплату этому сотруднику'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => openHistory(context),
              icon: const Icon(Icons.history_rounded),
              label: const Text('История выплат сотрудника'),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountingPaymentDetailScreen extends StatefulWidget {
  final AccountingPaymentRegisterRow row;

  const AccountingPaymentDetailScreen({super.key, required this.row});

  @override
  State<AccountingPaymentDetailScreen> createState() =>
      _AccountingPaymentDetailScreenState();
}

class _AccountingPaymentDetailScreenState
    extends State<AccountingPaymentDetailScreen> {
  late Future<PaymentRecord?> future;
  bool addingReceipt = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<PaymentRecord?> load({bool forceRefresh = false}) async {
    final payments = await PaymentRepository.fetchPaymentsForEmployee(
      widget.row.employeeId,
      forceRefresh: forceRefresh,
    );
    for (final payment in payments) {
      if (payment.id == widget.row.paymentId) return payment;
    }
    return null;
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Future<void> addReceipt(PaymentRecord payment) async {
    if (addingReceipt) return;
    setState(() => addingReceipt = true);
    try {
      final files = await PaymentReceiptRepository.pickReceiptFiles();
      if (files.isEmpty) return;
      await PaymentRepository.addReceiptsToPayment(
        paymentId: payment.id,
        employeeId: payment.employeeId,
        receiptFiles: files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Чеки добавлены: ${files.length}')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить чек: $error')),
      );
    } finally {
      if (mounted) setState(() => addingReceipt = false);
    }
  }

  Future<void> openHistory() async {
    final employee = widget.row.employee;
    if (employee == null) return;
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => PaymentHistoryScreen(
          employee: employee,
          employeeIds: [widget.row.employeeId],
        ),
      ),
    );
    if (mounted) await refresh();
  }

  String paymentTypeLabel(String value) => switch (value) {
    'advance' => 'Аванс',
    'salary' => 'Заработная плата',
    'fine' => 'Штраф',
    _ => 'Другое',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Конкретная выплата'),
      ),
      body: PremiumWorkBackdrop(
        child: FutureBuilder<PaymentRecord?>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Ошибка: ${snapshot.error}'));
            }
            final payment = snapshot.data;
            if (payment == null) {
              return const Center(child: Text('Выплата не найдена'));
            }
            final hasReceipts = payment.receipts.isNotEmpty;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                PremiumWorkCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.row.employeeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.row.objectName,
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PlainLine(
                        title: 'Тип',
                        value: paymentTypeLabel(payment.paymentType),
                      ),
                      _PlainLine(
                        title: 'Сумма',
                        value: accountingMoney(payment.amount),
                      ),
                      _PlainLine(
                        title: 'Дата выплаты',
                        value: accountingDate(payment.paymentDate),
                      ),
                      _PlainLine(
                        title: 'Расчётный период',
                        value: accountingMonth(
                          DateTime(payment.periodYear, payment.periodMonth, 1),
                        ),
                      ),
                      if (payment.comment.trim().isNotEmpty)
                        _PlainLine(
                          title: 'Комментарий',
                          value: payment.comment.trim(),
                        ),
                      const Divider(height: 28),
                      Row(
                        children: [
                          Icon(
                            hasReceipts
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            color: hasReceipts
                                ? AppAdaptivePalette.success
                                : AppAdaptivePalette.danger,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              hasReceipts
                                  ? 'Подтверждающих чеков: ${payment.receipts.length}'
                                  : 'Подтверждающий чек не приложен',
                              style: TextStyle(
                                color: hasReceipts
                                    ? AppAdaptivePalette.success
                                    : AppAdaptivePalette.danger,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: addingReceipt ? null : () => addReceipt(payment),
                  icon: addingReceipt
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(
                    addingReceipt
                        ? 'Загрузка...'
                        : hasReceipts
                        ? 'Добавить ещё чек'
                        : 'Приложить чек к этой выплате',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: openHistory,
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('Вся история выплат сотрудника'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String title;
  final String value;
  final bool prominent;

  const _DetailLine({
    required this.title,
    required this.value,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: prominent
            ? AppAdaptivePalette.accentSoft
            : AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: prominent ? 20 : 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainLine extends StatelessWidget {
  final String title;
  final String value;

  const _PlainLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayDetailsData {
  final List<MonthlyTimesheetRow> balances;
  final List<AccountingPaymentRegisterRow> payments;

  const _TodayDetailsData({
    this.balances = const [],
    this.payments = const [],
  });
}
