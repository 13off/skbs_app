import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import '../data/employee_work_action_repository.dart';

class EmployeeWorkHomeScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeWorkHomeScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EmployeeWorkHomeScreen> createState() => _EmployeeWorkHomeScreenState();
}

class _EmployeeWorkHomeScreenState extends State<EmployeeWorkHomeScreen> {
  late Future<EmployeeCabinetData> future;

  @override
  void initState() {
    super.initState();
    future = EmployeeCabinetRepository.fetch();
  }

  Future<void> refresh() async {
    final next = EmployeeCabinetRepository.fetch();
    setState(() => future = next);
    await next;
  }

  Future<void> openTask(EmployeeCabinetTask task) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeWorkTaskDetailsScreen(
          task: task,
          onChanged: refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EmployeeCabinetView(
      future: future,
      onRefresh: refresh,
      title: 'Главная',
      builder: (data) {
        final task = data.currentTask;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmployeeCard(data: data),
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _IconTile(icon: Icons.construction_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task == null ? 'На сегодня задач нет' : 'Текущая задача',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (task != null) _StatusBadge(text: task.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (task == null)
                    Text(
                      'Новая задача появится здесь после назначения мастером.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                    )
                  else ...[
                    Text(
                      task.work.trim().isEmpty ? 'Рабочая задача' : task.work,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      <String>[
                        if (task.axes.trim().isNotEmpty) task.axes.trim(),
                        if (task.objectName.trim().isNotEmpty)
                          task.objectName.trim(),
                        if (task.date != null) _formatDate(task.date!),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 18),
                    PremiumActionButton(
                      label: task.status == 'Запланировано'
                          ? 'Начать работу'
                          : 'Открыть задачу',
                      icon: task.status == 'Запланировано'
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: () => openTask(task),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_month_rounded,
                    value: _formatDecimal(data.summary.shifts),
                    label: 'смен в месяце',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.verified_rounded,
                    value: '${data.summary.completedTasks}',
                    label: 'задач выполнено',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Этот месяц',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  _ValueLine(
                    title: 'Предварительно начислено',
                    value: _formatMoney(data.summary.estimatedAccrued),
                  ),
                  _ValueLine(
                    title: 'Выплаты и авансы',
                    value: _formatMoney(data.summary.paidCurrentMonth),
                  ),
                  _ValueLine(
                    title: 'Задач в работе',
                    value: '${data.summary.plannedTasks}',
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

class EmployeeWorkTasksScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeWorkTasksScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EmployeeWorkTasksScreen> createState() => _EmployeeWorkTasksScreenState();
}

class _EmployeeWorkTasksScreenState extends State<EmployeeWorkTasksScreen> {
  late Future<EmployeeCabinetData> future;
  bool showCompleted = false;

  @override
  void initState() {
    super.initState();
    future = EmployeeCabinetRepository.fetch();
  }

  Future<void> refresh() async {
    final next = EmployeeCabinetRepository.fetch();
    setState(() => future = next);
    await next;
  }

  Future<void> openTask(EmployeeCabinetTask task) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeWorkTaskDetailsScreen(
          task: task,
          onChanged: refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EmployeeCabinetView(
      future: future,
      onRefresh: refresh,
      title: 'Задачи',
      builder: (data) {
        final tasks = data.tasks
            .where((task) => task.isCompleted == showCompleted)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.pending_actions_rounded),
                  label: Text('В работе'),
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.task_alt_rounded),
                  label: Text('Выполнено'),
                ),
              ],
              selected: <bool>{showCompleted},
              onSelectionChanged: (selection) {
                setState(() => showCompleted = selection.first);
              },
            ),
            const SizedBox(height: 14),
            if (tasks.isEmpty)
              _EmptyCard(
                title: showCompleted
                    ? 'Выполненных задач пока нет'
                    : 'Задач в работе пока нет',
                text: showCompleted
                    ? 'Завершённые задачи появятся здесь.'
                    : 'Назначенные мастером задачи появятся автоматически.',
              )
            else
              for (var index = 0; index < tasks.length; index++) ...[
                PremiumWorkCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    onTap: () => openTask(tasks[index]),
                    leading: const _IconTile(icon: Icons.assignment_outlined),
                    title: Text(
                      tasks[index].work.trim().isEmpty
                          ? 'Рабочая задача'
                          : tasks[index].work,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        <String>[
                          if (tasks[index].axes.trim().isNotEmpty)
                            tasks[index].axes.trim(),
                          if (tasks[index].objectName.trim().isNotEmpty)
                            tasks[index].objectName.trim(),
                          if (tasks[index].date != null)
                            _formatDate(tasks[index].date!),
                        ].join(' · '),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                if (index != tasks.length - 1) const SizedBox(height: 12),
              ],
          ],
        );
      },
    );
  }
}

class EmployeeWorkTaskDetailsScreen extends StatefulWidget {
  final EmployeeCabinetTask task;
  final Future<void> Function()? onChanged;

  const EmployeeWorkTaskDetailsScreen({
    super.key,
    required this.task,
    this.onChanged,
  });

  @override
  State<EmployeeWorkTaskDetailsScreen> createState() =>
      _EmployeeWorkTaskDetailsScreenState();
}

class _EmployeeWorkTaskDetailsScreenState
    extends State<EmployeeWorkTaskDetailsScreen> {
  late EmployeeCabinetTask task;
  bool isStarting = false;
  String? uploadingStage;

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  Future<void> reloadTask() async {
    final data = await EmployeeCabinetRepository.fetch();
    for (final item in data.tasks) {
      if (item.id == task.id) {
        if (mounted) setState(() => task = item);
        return;
      }
    }
  }

  Future<void> startTask() async {
    if (isStarting || task.isCompleted) return;
    setState(() => isStarting = true);
    try {
      await EmployeeWorkActionRepository.startTask(task.id);
      await reloadTask();
      await widget.onChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Работа по задаче начата')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    } finally {
      if (mounted) setState(() => isStarting = false);
    }
  }

  Future<void> addPhotos(String stage) async {
    if (uploadingStage != null || task.isCompleted) return;
    try {
      final photos = await TaskRepository.pickPhotoFiles();
      if (photos.isEmpty || !mounted) return;
      setState(() => uploadingStage = stage);
      await EmployeeWorkActionRepository.uploadTaskPhotos(
        taskId: task.id,
        stage: stage,
        photos: photos,
      );
      await reloadTask();
      await widget.onChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Добавлено фотографий: ${photos.length}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    } finally {
      if (mounted) setState(() => uploadingStage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !task.isCompleted && task.status != 'В работе';
    return AppPage(
      title: 'Задача',
      subtitle: <String>[
        if (task.objectName.trim().isNotEmpty) task.objectName.trim(),
        if (task.date != null) _formatDate(task.date!),
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconTile(icon: Icons.assignment_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.work.trim().isEmpty ? 'Рабочая задача' : task.work,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(text: task.status),
                  ],
                ),
                const SizedBox(height: 14),
                if (task.axes.trim().isNotEmpty)
                  _DetailLine(icon: Icons.grid_4x4_rounded, text: task.axes),
                if (task.photoRequirementsEnforced)
                  const _DetailLine(
                    icon: Icons.photo_camera_outlined,
                    text: 'Для задачи предусмотрены фотографии «До» и «После»',
                  ),
                if (canStart) ...[
                  const SizedBox(height: 16),
                  PremiumActionButton(
                    label: 'Начать работу',
                    icon: Icons.play_arrow_rounded,
                    isLoading: isStarting,
                    onPressed: isStarting ? null : startTask,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PhotoSection(
            title: 'Фото до',
            photos: task.beforePhotos,
            isUploading: uploadingStage == 'before',
            enabled: !task.isCompleted && uploadingStage == null,
            onAdd: () => addPhotos('before'),
          ),
          const SizedBox(height: 14),
          _PhotoSection(
            title: 'Фото после',
            photos: task.afterPhotos,
            isUploading: uploadingStage == 'after',
            enabled: !task.isCompleted && uploadingStage == null,
            onAdd: () => addPhotos('after'),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCabinetView extends StatelessWidget {
  final Future<EmployeeCabinetData> future;
  final Future<void> Function() onRefresh;
  final String title;
  final Widget Function(EmployeeCabinetData data) builder;

  const _EmployeeCabinetView({
    required this.future,
    required this.onRefresh,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return AppPage(
            title: title,
            child: const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: title,
            subtitle: 'Не удалось загрузить данные',
            onRefresh: onRefresh,
            child: _EmptyCard(
              title: 'Ошибка загрузки',
              text: _errorText(snapshot.error),
            ),
          );
        }
        final data = snapshot.data!;
        return AppPage(
          title: title,
          subtitle: data.currentObject.trim().isEmpty
              ? 'Личный кабинет сотрудника'
              : 'Объект: ${data.currentObject.trim()}',
          onRefresh: onRefresh,
          child: builder(data),
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeCabinetData data;

  const _EmployeeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data.fullName.trim().isEmpty ? 'Сотрудник' : data.fullName.trim();
    return PremiumWorkCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppAdaptivePalette.accentSoft,
            child: Text(
              _initials(name),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  <String>[
                    if (data.profession.trim().isNotEmpty) data.profession.trim(),
                    if (data.phone.trim().isNotEmpty) data.phone.trim(),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final List<EmployeeCabinetTaskPhoto> photos;
  final bool isUploading;
  final bool enabled;
  final VoidCallback onAdd;

  const _PhotoSection({
    required this.title,
    required this.photos,
    required this.isUploading,
    required this.enabled,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title · ${photos.length}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: enabled ? onAdd : null,
                icon: isUploading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(isUploading ? 'Загрузка' : 'Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            Text(
              'Фотографий пока нет',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 640 ? 4 : 3;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos.map((photo) {
                    return SizedBox(
                      width: width,
                      height: width,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: photo.signedUrl.trim().isEmpty
                            ? const ColoredBox(
                                color: Colors.black12,
                                child: Icon(Icons.broken_image_outlined),
                              )
                            : Image.network(
                                photo.signedUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: Colors.black12,
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final completed = text == 'Выполнено';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppAdaptivePalette.success.withValues(alpha: 0.13)
            : AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.trim().isEmpty ? 'Запланировано' : text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 9),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  final String title;
  final String value;

  const _ValueLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String text;

  const _EmptyCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          const _IconTile(icon: Icons.assignment_outlined),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

String _errorText(Object? error) {
  return error
          ?.toString()
          .replaceFirst('Exception: ', '')
          .trim()
          .isNotEmpty ==
      true
      ? error.toString().replaceFirst('Exception: ', '').trim()
      : 'Не удалось выполнить действие';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final value = parts.take(2).map((part) => part.substring(0, 1).toUpperCase()).join();
  return value.isEmpty ? 'С' : value;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatMoney(double value) {
  final rounded = value.round();
  final raw = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${rounded < 0 ? '−' : ''}${buffer.toString()} ₽';
}
