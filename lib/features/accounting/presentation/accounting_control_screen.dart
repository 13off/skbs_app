import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_repository.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';
import 'accounting_workspace_widgets.dart';

class AccountingControlScreen extends StatefulWidget {
  const AccountingControlScreen({super.key});

  @override
  State<AccountingControlScreen> createState() => _AccountingControlScreenState();
}

class _AccountingControlScreenState extends State<AccountingControlScreen> {
  final workbench = AccountingWorkbenchRepository();
  final client = Supabase.instance.client;
  String view = 'calendar';
  late Future<_ControlData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_ControlData> load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    final result = await Future.wait<dynamic>([
      workbench.fetchCalendarTasks(limit: 100),
      AccountingRepository.fetchDashboard(month: now),
      workbench.fetchDocuments(),
      _fetchTrialBalance(start, end),
    ]);
    return _ControlData(
      tasks: result[0] as List<AccountingCalendarTask>,
      dashboard: result[1] as AccountingDashboardData,
      documents: result[2] as List<AccountingPrimaryDocument>,
      trialBalance: result[3] as List<_TrialBalanceRow>,
    );
  }

  Future<List<_TrialBalanceRow>> _fetchTrialBalance(
    DateTime start,
    DateTime end,
  ) async {
    final raw = await client.rpc(
      'get_accounting_trial_balance',
      params: {
        'p_start_date': _date(start),
        'p_end_date': _date(end),
      },
    );
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => _TrialBalanceRow.fromMap(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> addTask() async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );
    if (draft == null) return;
    await workbench.createCalendarTask(
      dueDate: draft.date,
      title: draft.title,
      kind: draft.kind,
    );
    await refresh();
  }

  Future<void> addManualOperation() async {
    final draft = await showDialog<_ManualOperationDraft>(
      context: context,
      builder: (_) => const _AddManualOperationDialog(),
    );
    if (draft == null) return;
    final entry = await client
        .from('accounting_journal_entries')
        .insert({
          'entry_date': _date(DateTime.now()),
          'description': draft.description,
          'document_number': draft.documentNumber,
          'status': 'posted',
        })
        .select('id')
        .single();
    final entryId = entry['id']?.toString();
    if (entryId == null || entryId.isEmpty) return;
    await client.from('accounting_journal_lines').insert([
      {
        'entry_id': entryId,
        'account_code': draft.debitAccount,
        'debit': draft.amount,
        'credit': 0,
      },
      {
        'entry_id': entryId,
        'account_code': draft.creditAccount,
        'debit': 0,
        'credit': draft.amount,
      },
    ]);
    await refresh();
  }

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        if (view == 'calendar' || view == 'reporting')
          FilledButton.icon(
            onPressed: addTask,
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Добавить задачу'),
          ),
        if (view == 'osv')
          FilledButton.icon(
            onPressed: addManualOperation,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Ручная операция'),
          ),
      ],
    );
  }

  Widget calendar(List<AccountingCalendarTask> tasks) {
    if (tasks.isEmpty) {
      return const AccountingEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Обязательных задач пока нет',
        description:
            'Добавьте сроки зарплаты, налогов и отчётности — они будут видны бухгалтеру на главной.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 950,
      columns: const [
        SpecialistTableColumn('Срок', flex: 2),
        SpecialistTableColumn('Задача', flex: 6),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('', flex: 2),
      ],
      rows: tasks
          .map(
            (task) => SpecialistTableRowData(
              cells: [
                specialistCellText(accountingDate(task.dueDate)),
                specialistCellText(task.title, weight: FontWeight.w900),
                specialistCellText(_taskKind(task.kind)),
                AccountingStatusBadge(
                  label: task.status == 'done' ? 'Готово' : 'К выполнению',
                  color: task.status == 'done'
                      ? specialistSuccess
                      : specialistWarning,
                ),
                task.status == 'done'
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: () async {
                          await workbench.completeCalendarTask(task.id);
                          await refresh();
                        },
                        child: const Text('Выполнено'),
                      ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget checks(_ControlData data) {
    final attentionDocs = data.documents
        .where((e) => e.status == 'attention' || e.status == 'draft')
        .toList();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.receipt_long_outlined,
                label: 'Выплат без чека',
                value: '${data.dashboard.missingReceiptCount}',
                accent: data.dashboard.missingReceiptCount > 0
                    ? specialistDanger
                    : specialistSuccess,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.description_outlined,
                label: 'Документов на проверке',
                value: '${attentionDocs.length}',
                accent: attentionDocs.isNotEmpty
                    ? specialistWarning
                    : specialistSuccess,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SpecialistMetricCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'К выплате сотрудникам',
                value: accountingMoney(data.dashboard.totalBalance.abs()),
                accent: specialistWarning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (attentionDocs.isEmpty && data.dashboard.missingReceipts.isEmpty)
          const AccountingEmptyState(
            icon: Icons.verified_outlined,
            title: 'Критичных замечаний нет',
            description:
                'Выплаты подтверждены, первичные документы не требуют внимания.',
          )
        else ...[
          if (data.dashboard.missingReceipts.isNotEmpty)
            SpecialistDesktopTable(
              minWidth: 900,
              columns: const [
                SpecialistTableColumn('Дата', flex: 2),
                SpecialistTableColumn('Сотрудник', flex: 4),
                SpecialistTableColumn('Объект', flex: 3),
                SpecialistTableColumn('Сумма', flex: 2),
                SpecialistTableColumn('Проблема', flex: 2),
              ],
              rows: data.dashboard.missingReceipts
                  .map(
                    (row) => SpecialistTableRowData(
                      cells: [
                        specialistCellText(accountingDate(row.paymentDate)),
                        specialistCellText(
                          row.employeeName,
                          weight: FontWeight.w900,
                        ),
                        specialistCellText(row.objectName),
                        specialistCellText(accountingMoney(row.amount)),
                        AccountingStatusBadge(
                          label: 'Нет чека',
                          color: specialistDanger,
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          if (attentionDocs.isNotEmpty) ...[
            const SizedBox(height: 18),
            SpecialistDesktopTable(
              minWidth: 1050,
              columns: const [
                SpecialistTableColumn('Дата', flex: 2),
                SpecialistTableColumn('Документ', flex: 3),
                SpecialistTableColumn('Контрагент', flex: 4),
                SpecialistTableColumn('Сумма', flex: 2),
                SpecialistTableColumn('Статус', flex: 2),
              ],
              rows: attentionDocs
                  .map(
                    (row) => SpecialistTableRowData(
                      cells: [
                        specialistCellText(accountingDate(row.date)),
                        specialistCellText(
                          row.number.isEmpty ? 'Без номера' : row.number,
                          weight: FontWeight.w900,
                        ),
                        specialistCellText(row.counterparty),
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
          ],
        ],
      ],
    );
  }

  Widget osv(List<_TrialBalanceRow> rows) {
    if (rows.isEmpty) {
      return const AccountingEmptyState(
        icon: Icons.table_chart_outlined,
        title: 'ОСВ пока пустая',
        description:
            'После добавления ручных проводок здесь появятся обороты по бухгалтерским счетам.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 1150,
      columns: const [
        SpecialistTableColumn('Счёт', flex: 2),
        SpecialistTableColumn('Нач. Дт', flex: 2),
        SpecialistTableColumn('Нач. Кт', flex: 2),
        SpecialistTableColumn('Оборот Дт', flex: 2),
        SpecialistTableColumn('Оборот Кт', flex: 2),
        SpecialistTableColumn('Кон. Дт', flex: 2),
        SpecialistTableColumn('Кон. Кт', flex: 2),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              cells: [
                specialistCellText(row.accountCode, weight: FontWeight.w900),
                specialistCellText(accountingMoney(row.openingDebit)),
                specialistCellText(accountingMoney(row.openingCredit)),
                specialistCellText(accountingMoney(row.debitTurnover)),
                specialistCellText(accountingMoney(row.creditTurnover)),
                specialistCellText(accountingMoney(row.closingDebit)),
                specialistCellText(accountingMoney(row.closingCredit)),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget reporting(List<AccountingCalendarTask> tasks) {
    final reportingTasks = tasks
        .where(
          (e) =>
              e.kind == 'report' || e.kind == 'tax' || e.kind == 'salary',
        )
        .toList();
    return Column(
      children: [
        const SpecialistMessageCard(
          icon: Icons.outbox_outlined,
          title: 'Регламентированная отчётность',
          description:
              'В AppСтрой контролируем сроки и готовность данных. Формирование и отправка официальных деклараций остаётся в 1С/СБИС, чтобы не дублировать налоговый движок.',
        ),
        const SizedBox(height: 16),
        calendar(reportingTasks),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ControlData>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[
          AccountingSectionSwitcher(
            selected: view,
            items: const [
              ('calendar', 'Календарь', Icons.event_outlined),
              ('checks', 'Проверки', Icons.fact_check_outlined),
              ('osv', 'ОСВ', Icons.table_chart_outlined),
              ('reporting', 'Отчётность', Icons.outbox_outlined),
            ],
            onChanged: (value) => setState(() => view = value),
          ),
          const SizedBox(height: 16),
        ];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.fact_check_outlined,
              title: 'Загружаем контроль',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить контроль',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          children.add(
            switch (view) {
              'calendar' => calendar(data.tasks),
              'checks' => checks(data),
              'osv' => osv(data.trialBalance),
              'reporting' => reporting(data.tasks),
              _ => const SizedBox.shrink(),
            },
          );
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-control',
          title: 'Контроль',
          subtitle: 'Сроки, проверки, ОСВ и подготовка отчётности',
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

class _ControlData {
  final List<AccountingCalendarTask> tasks;
  final AccountingDashboardData dashboard;
  final List<AccountingPrimaryDocument> documents;
  final List<_TrialBalanceRow> trialBalance;

  const _ControlData({
    required this.tasks,
    required this.dashboard,
    required this.documents,
    required this.trialBalance,
  });
}

class _TrialBalanceRow {
  final String accountCode;
  final double openingDebit;
  final double openingCredit;
  final double debitTurnover;
  final double creditTurnover;
  final double closingDebit;
  final double closingCredit;

  const _TrialBalanceRow({
    required this.accountCode,
    required this.openingDebit,
    required this.openingCredit,
    required this.debitTurnover,
    required this.creditTurnover,
    required this.closingDebit,
    required this.closingCredit,
  });

  factory _TrialBalanceRow.fromMap(Map<String, dynamic> map) {
    double n(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return _TrialBalanceRow(
      accountCode: map['account_code']?.toString() ?? '',
      openingDebit: n('opening_debit'),
      openingCredit: n('opening_credit'),
      debitTurnover: n('debit_turnover'),
      creditTurnover: n('credit_turnover'),
      closingDebit: n('closing_debit'),
      closingCredit: n('closing_credit'),
    );
  }
}

class _TaskDraft {
  final DateTime date;
  final String title;
  final String kind;

  const _TaskDraft({
    required this.date,
    required this.title,
    required this.kind,
  });
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final title = TextEditingController();
  DateTime date = DateTime.now();
  String kind = 'report';

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Задача бухгалтера'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'Что нужно сделать',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(
                  value: 'report',
                  child: Text('Отчётность'),
                ),
                DropdownMenuItem(value: 'tax', child: Text('Налог')),
                DropdownMenuItem(
                  value: 'salary',
                  child: Text('Зарплата'),
                ),
                DropdownMenuItem(value: 'payment', child: Text('Платёж')),
                DropdownMenuItem(value: 'other', child: Text('Другое')),
              ],
              onChanged: (value) =>
                  setState(() => kind = value ?? 'report'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  initialDate: date,
                );
                if (selected != null) setState(() => date = selected);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(accountingDate(date)),
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
            if (title.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _TaskDraft(
                date: date,
                title: title.text.trim(),
                kind: kind,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _ManualOperationDraft {
  final String debitAccount;
  final String creditAccount;
  final double amount;
  final String description;
  final String documentNumber;

  const _ManualOperationDraft({
    required this.debitAccount,
    required this.creditAccount,
    required this.amount,
    required this.description,
    required this.documentNumber,
  });
}

class _AddManualOperationDialog extends StatefulWidget {
  const _AddManualOperationDialog();

  @override
  State<_AddManualOperationDialog> createState() =>
      _AddManualOperationDialogState();
}

class _AddManualOperationDialogState
    extends State<_AddManualOperationDialog> {
  final debit = TextEditingController();
  final credit = TextEditingController();
  final amount = TextEditingController();
  final description = TextEditingController();
  final documentNumber = TextEditingController();

  @override
  void dispose() {
    debit.dispose();
    credit.dispose();
    amount.dispose();
    description.dispose();
    documentNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ручная бухгалтерская операция'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: debit,
                    decoration: const InputDecoration(
                      labelText: 'Дебет счёта',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: credit,
                    decoration: const InputDecoration(
                      labelText: 'Кредит счёта',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              decoration: const InputDecoration(
                labelText: 'Содержание операции',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: documentNumber,
              decoration: const InputDecoration(
                labelText: 'Документ / основание',
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
            if (parsed == null ||
                parsed <= 0 ||
                debit.text.trim().isEmpty ||
                credit.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _ManualOperationDraft(
                debitAccount: debit.text.trim(),
                creditAccount: credit.text.trim(),
                amount: parsed,
                description: description.text.trim(),
                documentNumber: documentNumber.text.trim(),
              ),
            );
          },
          child: const Text('Провести'),
        ),
      ],
    );
  }
}
