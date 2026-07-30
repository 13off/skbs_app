import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import '../data/employee_work_action_repository.dart';

class EmployeeWorkHomeScreen extends StatelessWidget {
  final AppUserProfile profile;

  const EmployeeWorkHomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return _CabinetLoader(
      title: 'Главная',
      builder: (data, refresh) {
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
                      const _IconBox(Icons.construction_rounded),
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
                      if (task != null) _StatusBadge(task.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (task == null)
                    const Text(
                      'Новая задача появится здесь после назначения мастером.',
                    )
                  else ...[
                    Text(
                      task.work.trim().isEmpty ? 'Рабочая задача' : task.work,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(_taskMeta(task)),
                    const SizedBox(height: 18),
                    PremiumActionButton(
                      label: task.status == 'Запланировано'
                          ? 'Начать работу'
                          : 'Открыть задачу',
                      icon: task.status == 'Запланировано'
                          ? Icons.play_arrow_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: () => _openTask(context, task, refresh),
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
                    value: _decimal(data.summary.shifts),
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
                  const Text(
                    'Этот месяц',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  _ValueRow(
                    'Предварительно начислено',
                    _money(data.summary.estimatedAccrued),
                  ),
                  _ValueRow(
                    'Выплаты и авансы',
                    _money(data.summary.paidCurrentMonth),
                  ),
                  _ValueRow('Задач в работе', '${data.summary.plannedTasks}'),
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

  const EmployeeWorkTasksScreen({super.key, required this.profile});

  @override
  State<EmployeeWorkTasksScreen> createState() => _EmployeeWorkTasksScreenState();
}

class _EmployeeWorkTasksScreenState extends State<EmployeeWorkTasksScreen> {
  bool showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return _CabinetLoader(
      title: 'Задачи',
      builder: (data, refresh) {
        final tasks = data.tasks
            .where((task) => task.isCompleted == showCompleted)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(value: false, label: Text('В работе')),
                ButtonSegment<bool>(value: true, label: Text('Выполнено')),
              ],
              selected: <bool>{showCompleted},
              onSelectionChanged: (value) {
                setState(() => showCompleted = value.first);
              },
            ),
            const SizedBox(height: 14),
            if (tasks.isEmpty)
              _MessageCard(
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
                    onTap: () => _openTask(context, tasks[index], refresh),
                    leading: const _IconBox(Icons.assignment_outlined),
                    title: Text(
                      tasks[index].work.trim().isEmpty
                          ? 'Рабочая задача'
                          : tasks[index].work,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(_taskMeta(tasks[index])),
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

  Future<void> reload() async {
    final data = await EmployeeCabinetRepository.fetch();
    for (final item in data.tasks) {
      if (item.id == task.id && mounted) {
        setState(() => task = item);
        break;
      }
    }
  }

  Future<void> start() async {
    if (isStarting || task.isCompleted) return;
    setState(() => isStarting = true);
    try {
      await EmployeeWorkActionRepository.startTask(task.id);
      await reload();
      await widget.onChanged?.call();
      if (mounted) _message('Работа по задаче начата');
    } catch (error) {
      if (mounted) _message(_error(error));
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
      await reload();
      await widget.onChanged?.call();
      if (mounted) _message('Добавлено фотографий: ${photos.length}');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => uploadingStage = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !task.isCompleted && task.status != 'В работе';
    return AppPage(
      title: 'Задача',
      subtitle: _taskMeta(task),
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
                    const _IconBox(Icons.assignment_rounded),
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
                    _StatusBadge(task.status),
                  ],
                ),
                if (task.axes.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Оси: ${task.axes.trim()}'),
                ],
                if (task.photoRequirementsEnforced) ...[
                  const SizedBox(height: 8),
                  const Text('Для задачи предусмотрены фото «До» и «После».'),
                ],
                if (canStart) ...[
                  const SizedBox(height: 16),
                  PremiumActionButton(
                    label: 'Начать работу',
                    icon: Icons.play_arrow_rounded,
                    isLoading: isStarting,
                    onPressed: isStarting ? null : start,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PhotoCard(
            title: 'Фото до',
            photos: task.beforePhotos,
            loading: uploadingStage == 'before',
            enabled: !task.isCompleted && uploadingStage == null,
            onAdd: () => addPhotos('before'),
          ),
          const SizedBox(height: 14),
          _PhotoCard(
            title: 'Фото после',
            photos: task.afterPhotos,
            loading: uploadingStage == 'after',
            enabled: !task.isCompleted && uploadingStage == null,
            onAdd: () => addPhotos('after'),
          ),
        ],
      ),
    );
  }
}

class _CabinetLoader extends StatefulWidget {
  final String title;
  final Widget Function(
    EmployeeCabinetData data,
    Future<void> Function() refresh,
  ) builder;

  const _CabinetLoader({required this.title, required this.builder});

  @override
  State<_CabinetLoader> createState() => _CabinetLoaderState();
}

class _CabinetLoaderState extends State<_CabinetLoader> {
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return AppPage(
            title: widget.title,
            subtitle: 'Загружаем данные',
            child: const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: widget.title,
            subtitle: 'Не удалось загрузить данные',
            onRefresh: refresh,
            child: _MessageCard(
              title: 'Ошибка загрузки',
              text: _error(snapshot.error),
            ),
          );
        }
        final data = snapshot.data!;
        return AppPage(
          title: widget.title,
          subtitle: data.currentObject.trim().isEmpty
              ? 'Личный кабинет сотрудника'
              : 'Объект: ${data.currentObject.trim()}',
          onRefresh: refresh,
          child: widget.builder(data, refresh),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title;
  final List<EmployeeCabinetTaskPhoto> photos;
  final bool loading;
  final bool enabled;
  final VoidCallback onAdd;

  const _PhotoCard({
    required this.title,
    required this.photos,
    required this.loading,
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
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: enabled ? onAdd : null,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(loading ? 'Загрузка' : 'Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            const Text('Фотографий пока нет')
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
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: width,
                        height: width,
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 10),
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

class _ValueRow extends StatelessWidget {
  final String title;
  final String value;

  const _ValueRow(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String title;
  final String text;

  const _MessageCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          const _IconBox(Icons.assignment_outlined),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;

  const _IconBox(this.icon);

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

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.trim().isEmpty ? 'Запланировано' : text,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

Future<void> _openTask(
  BuildContext context,
  EmployeeCabinetTask task,
  Future<void> Function() refresh,
) async {
  await Navigator.of(context).push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => EmployeeWorkTaskDetailsScreen(
        task: task,
        onChanged: refresh,
      ),
    ),
  );
}

String _taskMeta(EmployeeCabinetTask task) {
  return <String>[
    if (task.axes.trim().isNotEmpty) task.axes.trim(),
    if (task.objectName.trim().isNotEmpty) task.objectName.trim(),
    if (task.date != null) _date(task.date!),
  ].join(' · ');
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final result = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return result.isEmpty ? 'С' : result;
}

String _decimal(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _money(double value) {
  final rounded = value.round();
  final raw = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${rounded < 0 ? '−' : ''}${buffer.toString()} ₽';
}

String _error(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось выполнить действие' : text;
}
