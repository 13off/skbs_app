import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_shift_action_repository.dart';
import '../data/employee_shift_runtime.dart';
import '../data/employee_task_cabinet_repository.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeWorkTasksScreen extends StatefulWidget {
  final AppUserProfile profile;
  final ValueNotifier<String> selectedEmployeeId;

  const EmployeeWorkTasksScreen({
    super.key,
    required this.profile,
    required this.selectedEmployeeId,
  });

  @override
  State<EmployeeWorkTasksScreen> createState() =>
      _EmployeeWorkTasksScreenState();
}

class _EmployeeWorkTasksScreenState extends State<EmployeeWorkTasksScreen> {
  final runtime = EmployeeShiftRuntime.instance;
  late Future<EmployeeTaskCabinetData> future;
  bool startingDay = false;
  bool finishingDay = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<EmployeeTaskCabinetData> load() async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
    );
    final employeeId = data.profile.employeeId;
    if (widget.selectedEmployeeId.value != employeeId) {
      widget.selectedEmployeeId.value = employeeId;
    }
    await runtime.bind(employeeId);
    await runtime.preparePermission();
    return data;
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> startDay(String employeeId) async {
    if (startingDay) return;
    setState(() => startingDay = true);
    try {
      await runtime.start(employeeId);
      if (mounted) _message('Рабочий день начат');
    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      _message(error.message);
      if (error.openSettingsRequired && !kIsWeb) {
        await _openSettingsDialog(error.message);
      }
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => startingDay = false);
    }
  }

  Future<void> finishDay() async {
    if (finishingDay) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить рабочий день?'),
        content: const Text(
          'После завершения продолжить этот рабочий день нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => finishingDay = true);
    try {
      await runtime.finish();
      if (mounted) _message('Рабочий день завершён');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => finishingDay = false);
    }
  }

  Future<void> _openSettingsDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен доступ в настройках'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await runtime.openSettings();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTaskCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Задачи',
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
          subtitle: data.profile.currentObject.trim().isEmpty
              ? null
              : 'Объект: ${data.profile.currentObject.trim()}',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WorkDayCard(
                runtime: runtime,
                employeeId: data.profile.employeeId,
                starting: startingDay,
                finishing: finishingDay,
                onStart: () => startDay(data.profile.employeeId),
                onFinish: finishDay,
              ),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                const _MessageCard(
                  title: 'Активных задач пока нет',
                  text:
                      'Назначенная мастером задача появится здесь автоматически.',
                )
              else
                for (var index = 0; index < tasks.length; index++) ...[
                  PremiumWorkCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      onTap: () => _openTask(
                        context,
                        employeeId: data.profile.employeeId,
                        task: tasks[index],
                        onChanged: refresh,
                      ),
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
  final ValueNotifier<String> selectedEmployeeId;

  const EmployeeWorkTaskHistoryScreen({
    super.key,
    required this.profile,
    required this.selectedEmployeeId,
  });

  @override
  State<EmployeeWorkTaskHistoryScreen> createState() =>
      _EmployeeWorkTaskHistoryScreenState();
}

class _EmployeeWorkTaskHistoryScreenState
    extends State<EmployeeWorkTaskHistoryScreen> {
  late DateTime selectedDate;
  late Future<EmployeeTaskCabinetData> future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    future = load();
  }

  Future<EmployeeTaskCabinetData> load() async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
    );
    if (widget.selectedEmployeeId.value != data.profile.employeeId) {
      widget.selectedEmployeeId.value = data.profile.employeeId;
    }
    await EmployeeShiftRuntime.instance.bind(data.profile.employeeId);
    return data;
  }

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
    setState(
      () => selectedDate = DateTime(picked.year, picked.month, picked.day),
    );
  }

  void changeDay(int delta) {
    setState(() => selectedDate = selectedDate.add(Duration(days: delta)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTaskCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'История задач',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'История задач',
            onRefresh: refresh,
            child: _MessageCard(
              title: 'Ошибка загрузки',
              text: _error(snapshot.error),
            ),
          );
        }

        final data = snapshot.data!;
        final tasks = data.tasks
            .where((task) {
              final date = task.date;
              return date != null &&
                  date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
            })
            .toList(growable: false);

        return AppPage(
          title: 'История задач',
          subtitle: data.profile.currentObject.trim().isEmpty
              ? null
              : 'Объект: ${data.profile.currentObject.trim()}',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                  _HistoryTaskCard(
                    task: tasks[index],
                    onOpen: () => _openTask(
                      context,
                      employeeId: data.profile.employeeId,
                      task: tasks[index],
                      onChanged: refresh,
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
  final String employeeId;
  final EmployeeTaskCabinetTask task;
  final Future<void> Function()? onChanged;

  const EmployeeWorkTaskDetailsScreen({
    super.key,
    required this.employeeId,
    required this.task,
    this.onChanged,
  });

  @override
  State<EmployeeWorkTaskDetailsScreen> createState() =>
      _EmployeeWorkTaskDetailsScreenState();
}

class _EmployeeWorkTaskDetailsScreenState
    extends State<EmployeeWorkTaskDetailsScreen> {
  final runtime = EmployeeShiftRuntime.instance;
  late EmployeeTaskCabinetTask task;
  bool startingTask = false;
  String? uploadingStage;

  @override
  void initState() {
    super.initState();
    task = widget.task;
    runtime.bind(widget.employeeId);
  }

  Future<void> reload() async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.employeeId,
    );
    for (final item in data.tasks) {
      if (item.id == task.id && mounted) {
        setState(() => task = item);
        break;
      }
    }
  }

  Future<void> startTask() async {
    if (startingTask || task.isCompleted || task.isInProgress) return;
    setState(() => startingTask = true);
    try {
      await EmployeeShiftActionRepository.startTask(
        employeeId: widget.employeeId,
        taskId: task.id,
      );
      await reload();
      await widget.onChanged?.call();
      if (mounted) _message('Выполнение задачи начато');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => startingTask = false);
    }
  }

  Future<void> addPhotos(String stage) async {
    if (uploadingStage != null || task.isCompleted || !task.isInProgress)
      return;
    try {
      final photos = await TaskRepository.pickPhotoFiles();
      if (photos.isEmpty || !mounted) return;
      setState(() => uploadingStage = stage);
      await EmployeeShiftActionRepository.uploadTaskPhotos(
        employeeId: widget.employeeId,
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
    return AppPage(
      title: 'Задача',
      subtitle: _taskMeta(task),
      child: ValueListenableBuilder<EmployeeWorkDaySnapshot>(
        valueListenable: runtime.state,
        builder: (context, workDay, _) {
          final workDayActive =
              workDay.employeeId == widget.employeeId && workDay.isActive;
          final canStartTask =
              workDayActive &&
              !task.isCompleted &&
              !task.isInProgress &&
              !startingTask;
          final canAddPhotos =
              workDayActive &&
              task.isInProgress &&
              !task.isCompleted &&
              uploadingStage == null;

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
                            task.work.trim().isEmpty
                                ? 'Рабочая задача'
                                : task.work,
                            style: Theme.of(context).textTheme.titleLarge
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
                    if (!workDayActive && !task.isCompleted)
                      const Text(
                        'Сначала начните рабочий день на главной.',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      )
                    else if (canStartTask)
                      PremiumActionButton(
                        label: 'Начать выполнение',
                        icon: Icons.play_arrow_rounded,
                        isLoading: startingTask,
                        onPressed: startTask,
                      )
                    else if (task.isInProgress)
                      const _TaskInProgressBanner()
                    else if (task.isCompleted)
                      const Text(
                        'Задача выполнена.',
                        style: TextStyle(fontWeight: FontWeight.w900),
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
                disabledText: task.isInProgress
                    ? 'Фотографии доступны во время рабочего дня.'
                    : 'Сначала нажмите «Начать выполнение».',
                onAdd: () => addPhotos('before'),
              ),
              const SizedBox(height: 14),
              _PhotoCard(
                title: 'Фото после',
                photos: task.afterPhotos,
                loading: uploadingStage == 'after',
                enabled: canAddPhotos,
                disabledText: task.isInProgress
                    ? 'Фотографии доступны во время рабочего дня.'
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

class _WorkDayCard extends StatelessWidget {
  final EmployeeShiftRuntime runtime;
  final String employeeId;
  final bool starting;
  final bool finishing;
  final VoidCallback onStart;
  final VoidCallback onFinish;

  const _WorkDayCard({
    required this.runtime,
    required this.employeeId,
    required this.starting,
    required this.finishing,
    required this.onStart,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EmployeeWorkDaySnapshot>(
      valueListenable: runtime.state,
      builder: (context, snapshot, _) {
        final active = snapshot.employeeId == employeeId && snapshot.isActive;
        final startedAt = active ? snapshot.shift?.startedAt : null;
        return PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IconBox(
                    active
                        ? Icons.work_history_rounded
                        : Icons.work_outline_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? 'Работа идёт' : 'Рабочий день не начат',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          active
                              ? (startedAt == null
                                    ? 'Рабочий день активен.'
                                    : 'Начало: ${_time(startedAt)}')
                              : 'Нажмите кнопку перед началом работы.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (active)
                OutlinedButton.icon(
                  onPressed: finishing ? null : onFinish,
                  icon: finishing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop_circle_outlined),
                  label: Text(
                    finishing ? 'Завершаем…' : 'Завершить рабочий день',
                  ),
                )
              else
                PremiumActionButton(
                  label: 'Начать работу',
                  icon: Icons.play_arrow_rounded,
                  isLoading: starting,
                  onPressed: starting ? null : onStart,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskInProgressBanner extends StatelessWidget {
  const _TaskInProgressBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppAdaptivePalette.success.withValues(alpha: 0.35),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.construction_rounded),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Задача выполняется.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final String title;
  final List<EmployeeTaskCabinetPhoto> photos;
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${photos.length}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (photos.isNotEmpty)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: photos
                  .where((photo) => photo.signedUrl.isNotEmpty)
                  .map(
                    (photo) => InkWell(
                      onTap: () => _openPhoto(context, photo.signedUrl),
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          photo.signedUrl,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox(
                            width: 112,
                            height: 112,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (photos.isNotEmpty) const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: enabled && !loading ? onAdd : null,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(loading ? 'Добавляем…' : 'Добавить'),
          ),
          if (!enabled) ...[
            const SizedBox(height: 8),
            Text(
              disabledText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPhoto(BuildContext context, String url) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.7,
                maxScale: 5,
                child: Center(child: Image.network(url, fit: BoxFit.contain)),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: SafeArea(
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTaskCard extends StatelessWidget {
  final EmployeeTaskCabinetTask task;
  final VoidCallback onOpen;

  const _HistoryTaskCard({required this.task, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const _IconBox(Icons.history_rounded),
        title: Text(
          task.work.trim().isEmpty ? 'Рабочая задача' : task.work,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(_taskMeta(task)),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Статус'),
              const Spacer(),
              _StatusBadge(task.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Фотографии'),
              const Spacer(),
              Text('${task.photos.length}'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Открыть задачу'),
            ),
          ),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }
}

Future<void> _openTask(
  BuildContext context, {
  required String employeeId,
  required EmployeeTaskCabinetTask task,
  required Future<void> Function() onChanged,
}) async {
  await Navigator.of(context).push<void>(
    AppPageRoute<void>(
      builder: (_) => EmployeeWorkTaskDetailsScreen(
        employeeId: employeeId,
        task: task,
        onChanged: onChanged,
      ),
    ),
  );
}

String _taskMeta(EmployeeTaskCabinetTask task) {
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
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _error(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось выполнить действие' : text;
}
