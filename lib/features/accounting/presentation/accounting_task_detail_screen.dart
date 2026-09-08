import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_detail_repository.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';

class AccountingTaskDetailScreen extends StatefulWidget {
  final String taskId;

  const AccountingTaskDetailScreen({super.key, required this.taskId});

  @override
  State<AccountingTaskDetailScreen> createState() =>
      _AccountingTaskDetailScreenState();
}

class _AccountingTaskDetailScreenState extends State<AccountingTaskDetailScreen> {
  final repository = AccountingDetailRepository();
  late Future<AccountingCalendarTask?> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<AccountingCalendarTask?> load() {
    return repository.fetchCalendarTask(widget.taskId);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String taskKind(String kind) => switch (kind) {
    'tax' => 'Налог',
    'report' => 'Отчётность',
    'salary' => 'Зарплата',
    'payment' => 'Платёж',
    _ => 'Другое',
  };

  Future<void> editTask(AccountingCalendarTask task) async {
    final draft = await showDialog<_TaskEditDraft>(
      context: context,
      builder: (_) => _TaskEditDialog(task: task),
    );
    if (draft == null) return;
    setState(() => busy = true);
    try {
      await repository.updateCalendarTask(
        taskId: task.id,
        dueDate: draft.date,
        title: draft.title,
        kind: draft.kind,
        status: task.status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Задача обновлена')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить задачу: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggleStatus(AccountingCalendarTask task) async {
    final nextStatus = task.status == 'done' ? 'open' : 'done';
    setState(() => busy = true);
    try {
      await repository.updateCalendarTask(
        taskId: task.id,
        dueDate: task.dueDate,
        title: task.title,
        kind: task.kind,
        status: nextStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus == 'done'
                ? 'Задача отмечена выполненной'
                : 'Задача возвращена в работу',
          ),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить статус: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  bool isOverdue(AccountingCalendarTask task) {
    if (task.status == 'done') return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    return due.isBefore(today);
  }

  Widget line(String title, String value) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Задача бухгалтера'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: FutureBuilder<AccountingCalendarTask?>(
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
                  child: Text('Не удалось загрузить задачу: ${snapshot.error}'),
                ),
              );
            }
            final task = snapshot.data;
            if (task == null) return const Center(child: Text('Задача не найдена'));
            final overdue = isOverdue(task);
            final statusText = task.status == 'done'
                ? 'Выполнено'
                : overdue
                    ? 'Просрочено'
                    : 'К выполнению';
            final statusColor = task.status == 'done'
                ? AppAdaptivePalette.success
                : overdue
                    ? AppAdaptivePalette.danger
                    : AppAdaptivePalette.warning;
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (busy) const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      line('Срок', accountingDate(task.dueDate)),
                      line('Тип', taskKind(task.kind)),
                      line('Статус', statusText),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => editTask(task),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Редактировать задачу'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : () => toggleStatus(task),
                          icon: Icon(
                            task.status == 'done'
                                ? Icons.replay_rounded
                                : Icons.check_circle_outline_rounded,
                          ),
                          label: Text(
                            task.status == 'done'
                                ? 'Вернуть в работу'
                                : 'Отметить выполненной',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TaskEditDraft {
  final DateTime date;
  final String title;
  final String kind;

  const _TaskEditDraft({
    required this.date,
    required this.title,
    required this.kind,
  });
}

class _TaskEditDialog extends StatefulWidget {
  final AccountingCalendarTask task;

  const _TaskEditDialog({required this.task});

  @override
  State<_TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<_TaskEditDialog> {
  late final TextEditingController title;
  late DateTime date;
  late String kind;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.task.title);
    date = widget.task.dueDate;
    kind = widget.task.kind;
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: date,
    );
    if (selected != null) setState(() => date = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать задачу'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Что нужно сделать'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(value: 'report', child: Text('Отчётность')),
                DropdownMenuItem(value: 'tax', child: Text('Налог')),
                DropdownMenuItem(value: 'salary', child: Text('Зарплата')),
                DropdownMenuItem(value: 'payment', child: Text('Платёж')),
                DropdownMenuItem(value: 'other', child: Text('Другое')),
              ],
              onChanged: (value) => setState(() => kind = value ?? kind),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: chooseDate,
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
              _TaskEditDraft(
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
