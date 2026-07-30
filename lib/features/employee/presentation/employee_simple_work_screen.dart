import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import '../data/employee_shift_tracking_service.dart';
import '../data/employee_work_action_repository.dart';

class EmployeeWorkTasksScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeWorkTasksScreen({super.key, required this.profile});

  @override
  State<EmployeeWorkTasksScreen> createState() =>
      _EmployeeWorkTasksScreenState();
}

class _EmployeeWorkTasksScreenState extends State<EmployeeWorkTasksScreen> {
  final tracking = EmployeeShiftTrackingService.instance;
  late Future<EmployeeCabinetData> future;
  bool isStartingShift = false;
  bool isFinishingShift = false;

  @override
  void initState() {
    super.initState();
    future = load();
    tracking.restoreActiveShift();
  }

  Future<EmployeeCabinetData> load() => EmployeeCabinetRepository.fetch();

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> startShift() async {
    if (isStartingShift || tracking.state.value.isActive) return;
    setState(() => isStartingShift = true);
    try {
      await tracking.startShift();
      await refresh();
      if (mounted) _message('Смена начата. Теперь можно начать выполнение задачи.');
    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      _message(error.message);
      if (error.openSettingsRequired && !kIsWeb) {
        await _showLocationSettings(error.message);
      }
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isStartingShift = false);
    }
  }

  Future<void> finishShift() async {
    if (isFinishingShift || !tracking.state.value.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить рабочий день?'),
        content: const Text(
          'Сохранится конечная геопозиция, после чего запись маршрута остановится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить смену'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => isFinishingShift = true);
    try {
      await tracking.finishShift();
      await refresh();
      if (mounted) _message('Рабочий день завершён');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isFinishingShift = false);
    }
  }

  Future<void> _showLocationSettings(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен доступ к геопозиции'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await tracking.openLocationSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openTask(EmployeeCabinetTask task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeWorkTaskDetailsScreen(task: task),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Задачи',
            subtitle: 'Загружаем данные',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'Задачи',
            subtitle: 'Не удалось загрузить данные',
            onRefresh: refresh,
            child: _MessageCard(
              title: 'Ошибка загрузки',
              text: _error(snapshot.error),
            ),
          );
        }
        final data = snapshot.data!;
        final tasks = data.tasks
            .where((task) => !task.isCompleted)
            .toList(growable: false);
        return AppPage(
          title: 'Задачи',
          subtitle: data.currentObject.trim().isEmpty
              ? 'Личный кабинет сотрудника'
              : 'Объект: ${data.currentObject.trim()}',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ShiftControlCard(
                tracking: tracking,
                isStarting: isStartingShift,
                isFinishing: isFinishingShift,
                onStart: startShift,
                onFinish: finishShift,
              ),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                const _MessageCard(
                  title: 'Активных задач пока нет',
                  text: 'Назначенная мастером задача появится здесь автоматически.',
                )
              else
                for (var index = 0; index < tasks.length; index++) ...[
                  PremiumWorkCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      onTap: () => openTask(tasks[index]),
                      leading: const _IconBox(Icons.assignment_outlined),
                      title: Text(
                        tasks[index].work.trim().isEmpty
                            ? 'Рабочая задача'
                            : tasks[index].work,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_taskMeta(tasks[index])),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  if (index != tasks.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class EmployeeWorkTaskHistoryScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeWorkTaskHistoryScreen({super.key, required this.profile});

  @override
  State<EmployeeWorkTaskHistoryScreen> createState() =>
      _EmployeeWorkTaskHistoryScreenState();
}

class _EmployeeWorkTaskHistoryScreenState
    extends State<EmployeeWorkTaskHistoryScreen> {
  late DateTime selectedDate;
  late Future<EmployeeCabinetData> future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    future = load();
  }

  Future<EmployeeCabinetData> load() => EmployeeCabinetRepository.fetch(
        year: selectedDate.year,
        month: selectedDate.month,
      );

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      helpText: 'История задач за дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked == null) return;
    selectedDate = DateTime(picked.year, picked.month, picked.day);
    await refresh();
  }

  Future<void> changeDay(int delta) async {
    selectedDate = selectedDate.add(Duration(days: delta));
    await refresh();
  }

  Future<void> openTask(EmployeeCabinetTask task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeWorkTaskDetailsScreen(task: task),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'История задач',
            subtitle: 'Загружаем данные',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'История задач',
            subtitle: 'Не удалось загрузить данные',
            onRefresh: refresh,
            child: _MessageCard(
              title: 'Ошибка загрузки',
              text: _error(snapshot.error),
            ),
          );
        }
        final data = snapshot.data!;
        final tasks = data.tasks.where((task) {
          final date = task.date;
          return date != null &&
              date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
        }).toList(growable: false);
        return AppPage(
          title: 'История задач',
          subtitle: data.currentObject.trim().isEmpty
              ? 'Выберите дату'
              : 'Объект: ${data.currentObject.trim()}',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий день',
                      onPressed: () => changeDay(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(_longDate(selectedDate)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующий день',
                      onPressed: () => changeDay(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                _MessageCard(
                  title: 'За ${_date(selectedDate)} задач нет',
                  text: 'Выберите другую дату в календаре.',
                )
              else
                for (var index = 0; index < tasks.length; index++) ...[
                  PremiumWorkCard(
                    padding: EdgeInsets.zero,
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      leading: const _IconBox(Icons.history_rounded),
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
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        const Divider(),
                        Row(
                          children: [
                            const Text('Статус'),
                            const Spacer(),
                            _StatusBadge(tasks[index].status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => openTask(tasks[index]),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('Открыть задачу'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != tasks.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class EmployeeWorkTaskDetailsScreen extends StatefulWidget {
  final EmployeeCabinetTask task;

  const EmployeeWorkTaskDetailsScreen({super.key, required this.task});

  @override
  State<EmployeeWorkTaskDetailsScreen> createState() =>
      _EmployeeWorkTaskDetailsScreenState();
}

class _EmployeeWorkTaskDetailsScreenState
    extends State<EmployeeWorkTaskDetailsScreen> {
  final tracking = EmployeeShiftTrackingService.instance;
  late EmployeeCabinetTask task;
  bool isStartingTask = false;
  String? uploadingStage;

  @override
  void initState() {
    super.initState();
    task = widget.task;
    tracking.restoreActiveShift();
  }

  Future<void> reload() async {
    final data = await EmployeeCabinetRepository.fetch(
      year: task.date?.year,
      month: task.date?.month,
    );
    for (final item in data.tasks) {
      if (item.id == task.id && mounted) {
        setState(() => task = item);
        return;
      }
    }
  }

  Future<void> startTask() async {
    if (isStartingTask || task.isCompleted || task.status == 'В работе') return;
    if (!tracking.state.value.isActive) {
      _message('Сначала начните смену на странице задач.');
      return;
    }
    setState(() => isStartingTask = true);
    try {
      await EmployeeWorkActionRepository.startTask(task.id);
      await reload();
      if (mounted) _message('Выполнение задачи начато');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isStartingTask = false);
    }
  }

  Future<void> addPhotos(String stage) async {
    final canUpload = tracking.state.value.isActive &&
        task.status == 'В работе' &&
        !task.isCompleted;
    if (uploadingStage != null || !canUpload) return;
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
    return AppPage(
      title: 'Задача',
      subtitle: _taskMeta(task),
      child: ValueListenableBuilder<EmployeeShiftTrackingSnapshot>(
        valueListenable: tracking.state,
        builder: (context, snapshot, _) {
          final shiftActive = snapshot.isActive;
          final taskInProgress = task.status == 'В работе';
          final canAddPhotos = shiftActive && taskInProgress && !task.isCompleted;
          return Column(
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
                    const SizedBox(height: 18),
                    if (!shiftActive)
                      const _InlineNotice(
                        text: 'Сначала начните смену на основной странице задач.',
                      )
                    else if (!task.isCompleted && !taskInProgress)
                      PremiumActionButton(
                        label: 'Начать выполнение',
                        icon: Icons.construction_rounded,
                        isLoading: isStartingTask,
                        onPressed: isStartingTask ? null : startTask,
                      )
                    else if (taskInProgress)
                      const _InlineNotice(
                        text: 'Задача выполняется. Можно прикреплять фото работ.',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _PhotoCard(
                title: 'Фото до',
                photos: task.beforePhotos,
                loading: uploadingStage == 'before',
                enabled: canAddPhotos,
                disabledText: taskInProgress
                    ? 'Начните смену, чтобы добавить фотографии.'
                    : 'Сначала нажмите «Начать выполнение».',
                onAdd: () => addPhotos('before'),
              ),
              const SizedBox(height: 14),
              _PhotoCard(
                title: 'Фото после',
                photos: task.afterPhotos,
                loading: uploadingStage == 'after',
                enabled: canAddPhotos,
                disabledText: taskInProgress
                    ? 'Начните смену, чтобы добавить фотографии.'
                    : 'Сначала нажмите «Начать выполнение».',
                onAdd: () => addPhotos('after'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ShiftControlCard extends StatelessWidget {
  final EmployeeShiftTrackingService tracking;
  final bool isStarting;
  final bool isFinishing;
  final VoidCallback onStart;
  final VoidCallback onFinish;

  const _ShiftControlCard({
    required this.tracking,
    required this.isStarting,
    required this.isFinishing,
    required this.onStart,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EmployeeShiftTrackingSnapshot>(
      valueListenable: tracking.state,
      builder: (context, snapshot, _) {
        final active = snapshot.isActive;
        return PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBox(
                    active
                        ? Icons.location_on_rounded
                        : Icons.location_off_outlined,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Смена идёт' : 'Смена не начата',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          active
                              ? (snapshot.message.isEmpty
                                  ? 'Маршрут записывается.'
                                  : snapshot.message)
                              : 'Начните рабочий день на объекте. После этого можно выполнять задачи.',
                        ),
                        if (active && snapshot.shift?.startedAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Начало: ${_time(snapshot.shift!.startedAt!)} · '
                            'точек: ${snapshot.shift!.routePointCount + snapshot.pendingPointCount}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!active)
                PremiumActionButton(
                  label: 'Начать смену',
                  icon: Icons.play_arrow_rounded,
                  isLoading: isStarting,
                  onPressed: isStarting ? null : onStart,
                )
              else
                OutlinedButton.icon(
                  onPressed: isFinishing ? null : onFinish,
                  icon: isFinishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    isFinishing ? 'Завершаем…' : 'Завершить рабочий день',
                  ),
                ),
              if (active && snapshot.webForegroundOnly) ...[
                const SizedBox(height: 10),
                const Text(
                  'В PWA маршрут записывается только пока приложение открыто.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title;
  final List<EmployeeCabinetTaskPhoto> photos;
  final bool loading;
  final bool enabled;
  final String disabledText;
  final VoidCallback onAdd;

  const _PhotoCard({
    required this.title,
    required this.photos,
    required this.loading,
    required this.enabled,
    required this.disabledText,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _IconBox(Icons.photo_library_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              Text('${photos.length}'),
            ],
          ),
          const SizedBox(height: 12),
          if (photos.isEmpty)
            Text(enabled ? 'Фотографий пока нет.' : disabledText)
          else
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 150,
                      child: Image.network(
                        photo.signedUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: enabled && !loading ? onAdd : null,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: Text(loading ? 'Загружаем…' : 'Добавить фото'),
          ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String text;

  const _InlineNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final label = status.trim().isEmpty ? 'Запланировано' : status.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

String _taskMeta(EmployeeCabinetTask task) {
  final parts = <String>[];
  if (task.axes.trim().isNotEmpty) parts.add('Оси: ${task.axes.trim()}');
  if (task.objectName.trim().isNotEmpty) parts.add(task.objectName.trim());
  if (task.date != null) parts.add(_date(task.date!));
  return parts.isEmpty ? 'Без дополнительных данных' : parts.join(' · ');
}

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year}';
}

String _longDate(DateTime value) {
  const months = <String>[
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];
  return '${value.day} ${months[value.month - 1]} ${value.year}';
}

String _time(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _error(Object? error) {
  return (error?.toString() ?? 'Неизвестная ошибка')
      .replaceFirst('Exception: ', '')
      .trim();
}
