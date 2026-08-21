import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import '../data/employee_shift_tracking_service.dart';
import '../data/employee_work_action_repository.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeWorkHomeScreen extends StatelessWidget {
  final AppUserProfile profile;

  const EmployeeWorkHomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return EmployeeWorkTasksScreen(profile: profile);
  }
}

class EmployeeWorkTasksScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeWorkTasksScreen({super.key, required this.profile});

  @override
  State<EmployeeWorkTasksScreen> createState() =>
      _EmployeeWorkTasksScreenState();
}

class _EmployeeWorkTasksScreenState extends State<EmployeeWorkTasksScreen> {
  final tracking = EmployeeShiftTrackingService.instance;

  @override
  void initState() {
    super.initState();
    tracking.restoreActiveShift();
  }

  @override
  Widget build(BuildContext context) {
    return _CabinetLoader(
      title: 'Задачи',
      builder: (data, refresh) {
        final tasks = data.tasks
            .where((task) => !task.isCompleted)
            .toList(growable: false);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShiftStatusCard(tracking: tracking),
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
                    onTap: () => _openTask(context, tasks[index], refresh),
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
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
    return _CabinetLoader(
      key: ValueKey('${selectedDate.year}-${selectedDate.month}'),
      title: 'История задач',
      year: selectedDate.year,
      month: selectedDate.month,
      builder: (data, refresh) {
        final tasks = data.tasks
            .where((task) {
              final date = task.date;
              return date != null &&
                  date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
            })
            .toList(growable: false);
        return Column(
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
                _HistoryTaskCard(
                  task: tasks[index],
                  onOpen: () => _openTask(context, tasks[index], refresh),
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
  final tracking = EmployeeShiftTrackingService.instance;
  late EmployeeCabinetTask task;
  bool isStarting = false;
  bool isFinishing = false;
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
        break;
      }
    }
  }

  Future<void> startShift() async {
    if (isStarting || task.isCompleted) return;
    setState(() => isStarting = true);
    try {
      await tracking.startShift(task.id);
      await reload();
      await widget.onChanged?.call();
      if (mounted) _message('Смена начата. Маршрут записывается.');
    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      _message(error.message);
      if (error.openSettingsRequired && !kIsWeb) {
        await _showOpenSettingsDialog(error.message);
      }
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isStarting = false);
    }
  }

  Future<void> finishShift() async {
    if (isFinishing || !tracking.state.value.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить рабочий день?'),
        content: const Text(
          'Будет сохранена конечная геопозиция, после чего запись маршрута остановится.',
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
    setState(() => isFinishing = true);
    try {
      await tracking.finishShift();
      await widget.onChanged?.call();
      if (mounted) _message('Рабочий день завершён');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isFinishing = false);
    }
  }

  Future<void> _showOpenSettingsDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен доступ «Всегда»'),
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

  Future<void> addPhotos(String stage) async {
    final snapshot = tracking.state.value;
    final belongsToTask = snapshot.activeShift?.taskId == task.id;
    if (uploadingStage != null || task.isCompleted || !belongsToTask) return;
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
    return AppPage(
      title: 'Задача',
      subtitle: _taskMeta(task),
      child: ValueListenableBuilder<EmployeeShiftTrackingSnapshot>(
        valueListenable: tracking.state,
        builder: (context, snapshot, _) {
          final activeShift = snapshot.activeShift;
          final shiftForThisTask = activeShift?.taskId == task.id;
          final canStart = !task.isCompleted && activeShift == null;
          final canAddPhotos =
              !task.isCompleted && shiftForThisTask && uploadingStage == null;
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
                    if (task.photoRequirementsEnforced) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Для задачи предусмотрены фото «До» и «После».',
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (canStart)
                      PremiumActionButton(
                        label: 'Начать смену',
                        icon: Icons.play_arrow_rounded,
                        isLoading: isStarting,
                        onPressed: isStarting ? null : startShift,
                      )
                    else if (shiftForThisTask)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ActiveShiftInline(snapshot: snapshot),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: isFinishing ? null : finishShift,
                            icon: isFinishing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              isFinishing
                                  ? 'Завершаем…'
                                  : 'Завершить рабочий день',
                            ),
                          ),
                        ],
                      )
                    else if (activeShift != null)
                      const Text(
                        'Сейчас активна другая задача. Сначала завершите текущую смену.',
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
                disabledText: shiftForThisTask
                    ? 'Добавьте фото участка перед началом работ.'
                    : 'Фото можно добавлять после начала смены.',
                onAdd: () => addPhotos('before'),
              ),
              const SizedBox(height: 14),
              _PhotoCard(
                title: 'Фото после',
                photos: task.afterPhotos,
                loading: uploadingStage == 'after',
                enabled: canAddPhotos,
                disabledText: shiftForThisTask
                    ? 'Добавьте фото результата работ.'
                    : 'Фото можно добавлять после начала смены.',
                onAdd: () => addPhotos('after'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CabinetLoader extends StatefulWidget {
  final String title;
  final int? year;
  final int? month;
  final Widget Function(
    EmployeeCabinetData data,
    Future<void> Function() refresh,
  )
  builder;

  const _CabinetLoader({
    super.key,
    required this.title,
    required this.builder,
    this.year,
    this.month,
  });

  @override
  State<_CabinetLoader> createState() => _CabinetLoaderState();
}

class _CabinetLoaderState extends State<_CabinetLoader> {
  late Future<EmployeeCabinetData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void didUpdateWidget(covariant _CabinetLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      future = load();
    }
  }

  Future<EmployeeCabinetData> load() {
    return EmployeeCabinetRepository.fetch(
      year: widget.year,
      month: widget.month,
    );
  }

  Future<void> refresh() async {
    final next = load();
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

class _ShiftStatusCard extends StatelessWidget {
  final EmployeeShiftTrackingService tracking;

  const _ShiftStatusCard({required this.tracking});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EmployeeShiftTrackingSnapshot>(
      valueListenable: tracking.state,
      builder: (context, snapshot, _) {
        final active = snapshot.isActive;
        return PremiumWorkCard(
          child: Row(
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
                          : 'Откройте назначенную задачу и нажмите «Начать смену».',
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
                    if (active && snapshot.webForegroundOnly) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'PWA не может гарантировать запись после сворачивания. '
                        'Для полного маршрута используйте установленное приложение.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveShiftInline extends StatelessWidget {
  final EmployeeShiftTrackingSnapshot snapshot;

  const _ActiveShiftInline({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final startedAt = snapshot.shift?.startedAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppAdaptivePalette.success.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed_rounded, color: AppAdaptivePalette.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              startedAt == null
                  ? 'Смена активна. Маршрут записывается.'
                  : 'Смена начата в ${_time(startedAt)}. Маршрут записывается.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTaskCard extends StatelessWidget {
  final EmployeeCabinetTask task;
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
              const Text('Фото до'),
              const Spacer(),
              Text('${task.beforePhotos.length}'),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Text('Фото после'),
              const Spacer(),
              Text('${task.afterPhotos.length}'),
            ],
          ),
          if (task.notDoneComment.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Комментарий: ${task.notDoneComment.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Открыть карточку задачи'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title · ${photos.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
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
          const SizedBox(height: 10),
          Text(
            enabled ? 'Фотографии прикрепляются к этой задаче.' : disabledText,
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
                  children: photos
                      .map((photo) {
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
                      })
                      .toList(growable: false),
                );
              },
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
        children: [
          const _IconBox(Icons.assignment_outlined),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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
    AppPageRoute<void>(
      builder: (_) =>
          EmployeeWorkTaskDetailsScreen(task: task, onChanged: refresh),
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
