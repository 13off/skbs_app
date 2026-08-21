import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/manager_todo_repository.dart';
import '../../../navigation/app_page_route.dart';

/// Kept for the old manager shell integration. The visible block now lives
/// inside the dashboard content via [ManagerTodoHomeSection].
class ManagerTodoHomeBar extends StatelessWidget {
  const ManagerTodoHomeBar({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class ManagerTodoHomeSection extends StatefulWidget {
  const ManagerTodoHomeSection({super.key});

  @override
  State<ManagerTodoHomeSection> createState() => _ManagerTodoHomeSectionState();
}

class _ManagerTodoHomeSectionState extends State<ManagerTodoHomeSection> {
  Future<List<ManagerTodoItem>>? future;
  final Set<String> busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    future = ManagerTodoRepository.fetchTodos(limit: 30);
  }

  Future<void> reload() async {
    final next = ManagerTodoRepository.fetchTodos(limit: 30);
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> openAll() async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(builder: (_) => const ManagerTodosScreen()),
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

  Future<void> complete(ManagerTodoItem item) async {
    if (busyIds.contains(item.id)) return;
    setState(() => busyIds.add(item.id));
    try {
      final changed = await ManagerTodoRepository.setDone(item.id, done: true);
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
    return FutureBuilder<List<ManagerTodoItem>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ManagerTodoItem>[];
        final visible = items.take(3).toList(growable: false);
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        'Дела',
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (items.isNotEmpty) ...[
                        const SizedBox(width: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
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
                ),
                TextButton(onPressed: openAll, child: const Text('Все дела')),
              ],
            ),
            const SizedBox(height: 8),
            PremiumWorkCard(
              radius: 22,
              padding: EdgeInsets.zero,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: LinearProgressIndicator(),
                    )
                  : snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Не удалось загрузить дела'),
                          ),
                          TextButton(
                            onPressed: reload,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppAdaptivePalette.surfaceSoft,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.task_alt_rounded,
                              color: AppAdaptivePalette.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Открытых дел нет',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Можно быстро записать то, что нельзя забыть.',
                                  style: TextStyle(
                                    color: AppAdaptivePalette.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: addTodo,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Добавить'),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index < visible.length;
                          index++
                        ) ...[
                          _ManagerTodoCompactRow(
                            item: visible[index],
                            busy: busyIds.contains(visible[index].id),
                            onToggle: () => complete(visible[index]),
                            onOpen: openAll,
                          ),
                          if (index != visible.length - 1)
                            Divider(
                              height: 1,
                              color: AppAdaptivePalette.border,
                            ),
                        ],
                        Divider(height: 1, color: AppAdaptivePalette.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: addTodo,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Добавить дело'),
                              ),
                              const Spacer(),
                              if (items.length > visible.length)
                                TextButton(
                                  onPressed: openAll,
                                  child: Text(
                                    'Ещё ${items.length - visible.length}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ManagerTodoCompactRow extends StatelessWidget {
  final ManagerTodoItem item;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ManagerTodoCompactRow({
    required this.item,
    required this.busy,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final reminder = formatManagerTodoReminder(item.reminderAt);
    return InkWell(
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Выполнено',
              visualDensity: VisualDensity.compact,
              onPressed: busy ? null : onToggle,
              icon: busy
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.radio_button_unchecked_rounded,
                      color: AppAdaptivePalette.textMuted,
                    ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.body.isNotEmpty || reminder.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.body.isNotEmpty ? item.body : reminder,
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
            if (item.isAutomatic) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: AppAdaptivePalette.textFaint,
              size: 21,
            ),
          ],
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
  bool showCompleted = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<ManagerTodoItem>> load() =>
      ManagerTodoRepository.fetchTodos(includeDone: true, limit: 200);

  Future<void> reload() async {
    final next = load();
    if (mounted) setState(() => future = next);
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
      if (mounted) {
        setState(() => showCompleted = false);
        await reload();
      }
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
      body: PremiumWorkBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 96),
                child: FutureBuilder<List<ManagerTodoItem>>(
                  future: future,
                  builder: (context, snapshot) {
                    final source = snapshot.data ?? const <ManagerTodoItem>[];
                    final open = source.where((item) => !item.isDone).toList();
                    final completed =
                        source.where((item) => item.isDone).toList()..sort(
                          (a, b) => (b.completedAt ?? b.createdAt).compareTo(
                            a.completedAt ?? a.createdAt,
                          ),
                        );
                    final visible = showCompleted ? completed : open;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              tooltip: 'Назад',
                              onPressed: () => Navigator.maybePop(context),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Дела',
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textPrimary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Открытые ${open.length}  ·  Выполненные ${completed.length}',
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: addTodo,
                              icon: const Icon(Icons.add_rounded, size: 19),
                              label: const Text('Добавить дело'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        PremiumWorkCard(
                          radius: 18,
                          padding: const EdgeInsets.all(5),
                          child: Row(
                            children: [
                              Expanded(
                                child: _TodoSegment(
                                  label: 'Открытые',
                                  count: open.length,
                                  selected: !showCompleted,
                                  onTap: () =>
                                      setState(() => showCompleted = false),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: _TodoSegment(
                                  label: 'Выполненные',
                                  count: completed.length,
                                  selected: showCompleted,
                                  onTap: () =>
                                      setState(() => showCompleted = true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child:
                              snapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !snapshot.hasData
                              ? const Center(child: CircularProgressIndicator())
                              : snapshot.hasError
                              ? _TodoStateCard(
                                  icon: Icons.error_outline_rounded,
                                  title: 'Не удалось загрузить дела',
                                  text: 'Проверь соединение и повтори.',
                                  actionLabel: 'Повторить',
                                  onAction: reload,
                                )
                              : visible.isEmpty
                              ? _TodoStateCard(
                                  icon: showCompleted
                                      ? Icons.history_rounded
                                      : Icons.task_alt_rounded,
                                  title: showCompleted
                                      ? 'Выполненных дел пока нет'
                                      : 'Открытых дел нет',
                                  text: showCompleted
                                      ? 'Здесь останется история закрытых дел.'
                                      : 'Добавь дело, если есть то, что нельзя забыть.',
                                  actionLabel: showCompleted
                                      ? 'К открытым'
                                      : 'Добавить дело',
                                  onAction: showCompleted
                                      ? () async => setState(
                                          () => showCompleted = false,
                                        )
                                      : addTodo,
                                )
                              : RefreshIndicator(
                                  onRefresh: reload,
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 24),
                                    itemCount: visible.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 9),
                                    itemBuilder: (context, index) {
                                      final item = visible[index];
                                      return _ManagerTodoTile(
                                        item: item,
                                        busy: busyIds.contains(item.id),
                                        onToggle: () => toggle(item),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodoSegment extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TodoSegment({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppAdaptivePalette.surfaceSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: AppAdaptivePalette.border)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppAdaptivePalette.textPrimary
                    : AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppAdaptivePalette.accentSoft
                    : AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? AppAdaptivePalette.accent
                      : AppAdaptivePalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final reminder = formatManagerTodoReminder(item.reminderAt);
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: item.isDone ? 'Вернуть в открытые' : 'Выполнено',
            onPressed: busy ? null : onToggle,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
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
          const SizedBox(width: 5),
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
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 16,
                        color: AppAdaptivePalette.textFaint,
                      ),
                      const SizedBox(width: 6),
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
          if (item.isDone) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: busy ? null : onToggle,
              child: const Text('Вернуть'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodoStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final Future<void> Function() onAction;

  const _TodoStateCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppAdaptivePalette.textMuted),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppAdaptivePalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
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

String formatManagerTodoReminder(DateTime? value) {
  if (value == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (date == today) return 'Сегодня · $time';
  if (date == today.add(const Duration(days: 1))) return 'Завтра · $time';
  return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} · $time';
}

Future<ManagerTodoDraft?> showManagerTodoComposer(BuildContext context) async {
  final controller = TextEditingController();
  DateTime? reminderAt;
  var canSubmit = false;
  String? reminderError;

  final result = await showDialog<ManagerTodoDraft>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickReminder() async {
            final now = DateTime.now();
            final initial = reminderAt ?? now.add(const Duration(hours: 1));
            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(now.year, now.month, now.day),
              lastDate: DateTime(now.year + 2, 12, 31),
              helpText: 'Дата уведомления',
              cancelText: 'Отмена',
              confirmText: 'Далее',
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
              helpText: 'Время уведомления',
              cancelText: 'Отмена',
              confirmText: 'Выбрать',
            );
            if (time == null) return;
            final picked = DateTime(
              date.year,
              date.month,
              date.day,
              time.hour,
              time.minute,
            );
            setDialogState(() {
              reminderAt = picked;
              reminderError = picked.isAfter(DateTime.now())
                  ? null
                  : 'Выбери время позже текущего';
            });
          }

          return Dialog(
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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
                      'Уведомление',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: pickReminder,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: reminderError == null
                                ? AppAdaptivePalette.border
                                : Theme.of(context).colorScheme.error,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              color: reminderAt == null
                                  ? AppAdaptivePalette.textMuted
                                  : AppAdaptivePalette.accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                reminderAt == null
                                    ? 'Выбрать дату и время'
                                    : formatManagerTodoReminder(reminderAt),
                                style: TextStyle(
                                  color: reminderAt == null
                                      ? AppAdaptivePalette.textMuted
                                      : AppAdaptivePalette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (reminderAt != null)
                              IconButton(
                                tooltip: 'Без уведомления',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => setDialogState(() {
                                  reminderAt = null;
                                  reminderError = null;
                                }),
                                icon: const Icon(Icons.close_rounded, size: 19),
                              )
                            else
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppAdaptivePalette.textFaint,
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (reminderError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        reminderError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                          onPressed: canSubmit && reminderError == null
                              ? () {
                                  if (reminderAt != null &&
                                      !reminderAt!.isAfter(DateTime.now())) {
                                    setDialogState(() {
                                      reminderError =
                                          'Выбери время позже текущего';
                                    });
                                    return;
                                  }
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
