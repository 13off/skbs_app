import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/manager_todo_repository.dart';

class ManagerTodoHomeBar extends StatefulWidget {
  const ManagerTodoHomeBar({super.key});

  @override
  State<ManagerTodoHomeBar> createState() => _ManagerTodoHomeBarState();
}

class _ManagerTodoHomeBarState extends State<ManagerTodoHomeBar> {
  Future<List<ManagerTodoItem>>? future;
  final Set<String> busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    future = ManagerTodoRepository.fetchTodos(limit: 20);
  }

  Future<void> reload() async {
    final next = ManagerTodoRepository.fetchTodos(limit: 20);
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> openAll() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ManagerTodosScreen()),
    );
    if (mounted) await reload();
  }

  Future<void> addTodo() async {
    final draft = await showManagerTodoComposer(context);
    if (draft == null || !mounted) return;

    try {
      await ManagerTodoRepository.createTodo(
        title: draft.title,
        reminderAt: draft.reminderAt,
      );
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить дело: $error')),
      );
    }
  }

  Future<void> toggle(ManagerTodoItem item) async {
    if (busyIds.contains(item.id)) return;
    setState(() => busyIds.add(item.id));
    try {
      await ManagerTodoRepository.setDone(item.id, done: !item.isDone);
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить дело: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: PremiumWorkCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: FutureBuilder<List<ManagerTodoItem>>(
              future: future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <ManagerTodoItem>[];
                final first = items.isEmpty ? null : items.first;
                final loading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                return Row(
                  children: [
                    InkWell(
                      onTap: openAll,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.checklist_rounded,
                          color: AppAdaptivePalette.accent,
                          size: 23,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: InkWell(
                        onTap: openAll,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Дела',
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (items.isNotEmpty) ...[
                                    const SizedBox(width: 7),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppAdaptivePalette.accentSoft,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${items.length}',
                                        style: TextStyle(
                                          color: AppAdaptivePalette.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                loading
                                    ? 'Загрузка…'
                                    : first?.title ?? 'На сегодня всё закрыто',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: first == null
                                      ? AppAdaptivePalette.textMuted
                                      : AppAdaptivePalette.textPrimary,
                                  fontSize: 13,
                                  fontWeight: first == null
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                              if (first != null && first.body.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  first.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (first != null)
                      IconButton(
                        tooltip: 'Выполнено',
                        onPressed: busyIds.contains(first.id)
                            ? null
                            : () => toggle(first),
                        icon: busyIds.contains(first.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: AppAdaptivePalette.textMuted,
                              ),
                      ),
                    IconButton(
                      tooltip: 'Добавить дело',
                      onPressed: addTodo,
                      icon: Icon(
                        Icons.add_rounded,
                        color: AppAdaptivePalette.accent,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Все дела',
                      onPressed: openAll,
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: AppAdaptivePalette.textMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ManagerTodosScreen extends StatefulWidget {
  const ManagerTodosScreen({super.key});

  @override
  State<ManagerTodosScreen> createState() => _ManagerTodosScreenState();
}

class _ManagerTodosScreenState extends State<ManagerTodosScreen> {
  Future<List<ManagerTodoItem>>? future;
  final Set<String> busyIds = <String>{};
  bool includeDone = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<ManagerTodoItem>> load() {
    return ManagerTodoRepository.fetchTodos(
      includeDone: includeDone,
      limit: 150,
    );
  }

  Future<void> reload() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> addTodo() async {
    final draft = await showManagerTodoComposer(context);
    if (draft == null || !mounted) return;
    try {
      await ManagerTodoRepository.createTodo(
        title: draft.title,
        reminderAt: draft.reminderAt,
      );
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить дело: $error')),
      );
    }
  }

  Future<void> toggle(ManagerTodoItem item) async {
    if (busyIds.contains(item.id)) return;
    setState(() => busyIds.add(item.id));
    try {
      final changed = await ManagerTodoRepository.setDone(
        item.id,
        done: !item.isDone,
      );
      if (!changed) throw StateError('Дело не найдено');
      if (mounted) await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить дело: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      appBar: AppBar(
        title: const Text('Дела'),
        actions: [
          IconButton(
            tooltip: includeDone ? 'Скрыть выполненные' : 'Показать выполненные',
            onPressed: () {
              setState(() {
                includeDone = !includeDone;
                future = load();
              });
            },
            icon: Icon(
              includeDone
                  ? Icons.visibility_off_outlined
                  : Icons.history_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Добавить дело',
            onPressed: addTodo,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<ManagerTodoItem>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _TodoMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить дела',
                  text: snapshot.error.toString(),
                  actionLabel: 'Повторить',
                  onAction: reload,
                );
              }

              final items = snapshot.data ?? const <ManagerTodoItem>[];
              if (items.isEmpty) {
                return _TodoMessage(
                  icon: Icons.task_alt_rounded,
                  title: 'Всё закрыто',
                  text: 'Добавь короткое дело, чтобы не держать его в голове.',
                  actionLabel: 'Добавить дело',
                  onAction: addTodo,
                );
              }

              return RefreshIndicator(
                onRefresh: reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ManagerTodoTile(
                      item: item,
                      busy: busyIds.contains(item.id),
                      onToggle: () => toggle(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addTodo,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }
}

class _ManagerTodoTile extends StatelessWidget {
  final ManagerTodoItem item;
  final bool busy;
  final VoidCallback onToggle;

  const _ManagerTodoTile({
    required this.item,
    required this.busy,
    required this.onToggle,
  });

  String reminderText(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (date == today) return 'Сегодня, $time';
    if (date == today.add(const Duration(days: 1))) return 'Завтра, $time';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final reminder = reminderText(item.reminderAt);

    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: item.isDone ? 'Вернуть в дела' : 'Выполнено',
              onPressed: busy ? null : onToggle,
              icon: busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      item.isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.isDone
                          ? AppAdaptivePalette.success
                          : AppAdaptivePalette.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: item.isDone
                              ? AppAdaptivePalette.textMuted
                              : AppAdaptivePalette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          decoration: item.isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (item.isAutomatic)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.accentSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Авто',
                          style: TextStyle(
                            color: AppAdaptivePalette.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (reminder.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 15,
                        color: AppAdaptivePalette.textFaint,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        reminder,
                        style: TextStyle(
                          color: AppAdaptivePalette.textFaint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _TodoMessage({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 34, color: AppAdaptivePalette.textMuted),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ManagerTodoDraft {
  final String title;
  final DateTime? reminderAt;

  const ManagerTodoDraft({required this.title, required this.reminderAt});
}

Future<ManagerTodoDraft?> showManagerTodoComposer(BuildContext context) async {
  final controller = TextEditingController();
  var reminderChoice = 0;
  var canSubmit = false;

  final result = await showDialog<ManagerTodoDraft>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Новое дело',
                            style: TextStyle(
                              color: AppAdaptivePalette.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 300,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Что нужно сделать?',
                        hintText: 'Например: позвонить поставщику',
                      ),
                      onChanged: (value) {
                        final next = value.trim().isNotEmpty;
                        if (next != canSubmit) {
                          setDialogState(() => canSubmit = next);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Напомнить',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Не напоминать'),
                          selected: reminderChoice == 0,
                          onSelected: (_) =>
                              setDialogState(() => reminderChoice = 0),
                        ),
                        ChoiceChip(
                          label: const Text('Через час'),
                          selected: reminderChoice == 1,
                          onSelected: (_) =>
                              setDialogState(() => reminderChoice = 1),
                        ),
                        ChoiceChip(
                          label: const Text('Завтра 08:00'),
                          selected: reminderChoice == 2,
                          onSelected: (_) =>
                              setDialogState(() => reminderChoice = 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: canSubmit
                              ? () {
                                  final now = DateTime.now();
                                  final reminderAt = switch (reminderChoice) {
                                    1 => now.add(const Duration(hours: 1)),
                                    2 => DateTime(
                                        now.year,
                                        now.month,
                                        now.day + 1,
                                        8,
                                      ),
                                    _ => null,
                                  };
                                  Navigator.pop(
                                    dialogContext,
                                    ManagerTodoDraft(
                                      title: controller.text.trim(),
                                      reminderAt: reminderAt,
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  controller.dispose();
  return result;
}
