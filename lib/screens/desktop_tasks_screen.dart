import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/task_repository.dart';
import '../features/developer/data/developer_policy_repository.dart';
import '../features/tasks/task_edit_policy.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui.dart';
import 'act_preview_screen.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _line => AppAdaptivePalette.border;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _surface => AppAdaptivePalette.surface;
Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;
Color get _input => AppAdaptivePalette.inputSurface;
Color get _success => AppAdaptivePalette.success;
Color get _planned => AppAdaptivePalette.accent;
Color get _problem => AppAdaptivePalette.warning;

class DesktopTasksScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const DesktopTasksScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<DesktopTasksScreen> createState() => _DesktopTasksScreenState();
}

class _DesktopTasksScreenState extends State<DesktopTasksScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  DateTime selectedDate = AppState.today;
  List<TaskItemData> tasks = const <TaskItemData>[];
  String statusFilter = 'Все статусы';
  String? objectFilter;
  bool isLoading = true;
  String? loadError;
  int loadToken = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    objectFilter = cleanObjectName(widget.selectedObjectName);
    loadTasks();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant DesktopTasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (cleanObjectName(oldWidget.selectedObjectName) !=
        cleanObjectName(widget.selectedObjectName)) {
      objectFilter = cleanObjectName(widget.selectedObjectName);
      statusFilter = 'Все статусы';
      searchController.clear();
      loadTasks(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  bool isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String shortDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

  String longDate(DateTime date) {
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
    const weekDays = <String>[
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];

    return '${date.day} ${months[date.month - 1]} · ${weekDays[date.weekday - 1]}';
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted ||
        !change.affectsAny(const <AppDataDomain>{
          AppDataDomain.tasks,
          AppDataDomain.objects,
        })) {
      return;
    }

    loadTasks(silent: true, forceRefresh: true);
  }

  Future<void> loadTasks({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final token = ++loadToken;

    if (!silent) {
      setState(() {
        isLoading = true;
        loadError = null;
      });
    }

    try {
      final loaded = await TaskRepository.fetchTasksForDate(
        selectedDate,
        objectName: widget.selectedObjectName,
        forceRefresh: forceRefresh,
      );

      if (!mounted || token != loadToken) return;

      setState(() {
        tasks = loaded;
        isLoading = false;
        loadError = null;

        final availableObjects = loaded
            .map((task) => task.objectName.trim())
            .where((name) => name.isNotEmpty)
            .toSet();
        final lockedObject = cleanObjectName(widget.selectedObjectName);
        if (lockedObject != null) {
          objectFilter = lockedObject;
        } else if (objectFilter != null &&
            !availableObjects.contains(objectFilter)) {
          objectFilter = null;
        }

        final availableStatuses = loaded
            .map((task) => task.status.trim())
            .where((status) => status.isNotEmpty)
            .toSet();
        if (statusFilter != 'Все статусы' &&
            !availableStatuses.contains(statusFilter)) {
          statusFilter = 'Все статусы';
        }
      });
    } catch (error) {
      if (!mounted || token != loadToken) return;

      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }
  }

  void changeDate(DateTime date) {
    final cleanDate = DateTime(date.year, date.month, date.day);
    if (isSameDate(cleanDate, selectedDate)) return;

    setState(() {
      selectedDate = cleanDate;
    });
    loadTasks();
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (picked != null) changeDate(picked);
  }

  String? get createObjectName {
    return cleanObjectName(widget.selectedObjectName) ??
        cleanObjectName(objectFilter);
  }

  bool get canCreateTask {
    return createObjectName != null &&
        TaskEditPolicy.canCreateForDate(widget.profile, selectedDate);
  }

  Future<void> openAddTaskScreen() async {
    final objectName = createObjectName;

    if (objectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите конкретный объект в фильтре')),
      );
      return;
    }

    await DeveloperPolicyRepository.ensurePolicy(objectName);

    if (!TaskEditPolicy.canCreateForDate(
      widget.profile,
      selectedDate,
      objectName: objectName,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Прораб может добавлять задачи только на текущий день'),
        ),
      );
      return;
    }

    final draft = await Navigator.push<TaskCreateDraft>(
      context,
      CupertinoPageRoute<TaskCreateDraft>(
        builder: (_) => AddTaskScreen(
          initialDate: selectedDate,
          objectName: objectName,
          allowAnyDate:
              widget.profile.isAdmin ||
              TaskEditPolicy.forObject(objectName).foremanCanCreateAnyDate,
        ),
      ),
    );

    if (draft == null) return;

    final createdTask = await TaskRepository.addTaskWithDetails(
      draft.task,
      objectName: objectName,
      assigneeIds: draft.assigneeIds,
      photos: draft.photos,
    );

    if (!mounted) return;

    final draftDate = DateTime(
      draft.task.date.year,
      draft.task.date.month,
      draft.task.date.day,
    );

    if (!isSameDate(draftDate, selectedDate)) {
      setState(() => selectedDate = draftDate);
      await loadTasks();
      return;
    }

    setState(() {
      tasks = <TaskItemData>[
        ...tasks.where((task) => task.id != createdTask.id),
        createdTask,
      ];
    });
  }

  bool taskBelongsToLoadedScope(TaskItemData task) {
    if (!isSameDate(task.date, selectedDate)) return false;
    final selectedObject = cleanObjectName(widget.selectedObjectName);
    return selectedObject == null ||
        cleanObjectName(task.objectName) == selectedObject;
  }

  Future<void> openTaskDetails(TaskItemData task) async {
    final result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),
    );

    if (result == null) return;

    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
      if (!mounted) return;
      setState(() {
        tasks = tasks.where((item) => item.id != task.id).toList();
      });
      return;
    }

    if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
      if (!mounted) return;

      setState(() {
        final next = <TaskItemData>[];
        var replaced = false;

        for (final item in tasks) {
          if (item.id == result.id) {
            replaced = true;
            if (taskBelongsToLoadedScope(result)) next.add(result);
          } else {
            next.add(item);
          }
        }

        if (!replaced && taskBelongsToLoadedScope(result)) next.add(result);
        tasks = next;
      });
    }
  }

  List<String> get objectOptions {
    final names =
        tasks
            .map((task) => task.objectName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  List<String> get statusOptions {
    final statuses =
        tasks
            .map((task) => task.status.trim())
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return <String>['Все статусы', ...statuses];
  }

  List<TaskItemData> visibleTasks() {
    final query = searchController.text.trim().toLowerCase();
    final selectedObject = cleanObjectName(objectFilter);

    final visible = tasks.where((task) {
      if (selectedObject != null &&
          cleanObjectName(task.objectName) != selectedObject) {
        return false;
      }
      if (statusFilter != 'Все статусы' && task.status != statusFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      return task.work.toLowerCase().contains(query) ||
          task.axes.toLowerCase().contains(query) ||
          task.objectName.toLowerCase().contains(query) ||
          task.status.toLowerCase().contains(query) ||
          task.notDoneComment.toLowerCase().contains(query);
    }).toList();

    visible.sort((first, second) {
      final status = statusPriority(
        first.status,
      ).compareTo(statusPriority(second.status));
      if (status != 0) return status;
      final object = first.objectName.compareTo(second.objectName);
      if (object != 0) return object;
      return first.work.compareTo(second.work);
    });

    return visible;
  }

  int statusPriority(String status) {
    switch (status) {
      case 'Запланировано':
        return 0;
      case 'В работе':
        return 1;
      case 'Выполнено':
        return 3;
      default:
        return 2;
    }
  }

  List<TaskItemData> actTasks() {
    final selectedObject = cleanObjectName(objectFilter);
    if (selectedObject == null) return tasks;
    return tasks
        .where((task) => cleanObjectName(task.objectName) == selectedObject)
        .toList();
  }

  void openActPreview() {
    final source = actTasks();
    if (!widget.profile.isAdmin || source.isEmpty) return;

    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => ActPreviewScreen(tasks: source, date: selectedDate),
      ),
    );
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      statusFilter = 'Все статусы';
      objectFilter = cleanObjectName(widget.selectedObjectName);
    });
  }

  Widget buildHeader() {
    return AppPageHeader(
      title: 'Задачи',
      subtitle:
          'ПК-вид · работы по осям, объектам и статусам за выбранную дату',
      trailing: IconButton(
        onPressed: () => loadTasks(forceRefresh: true),
        tooltip: 'Обновить задачи',
        icon: Icon(Icons.refresh_rounded),
      ),
    );
  }

  Widget buildToolbar() {
    final sourceForAct = actTasks();

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _SquareButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Предыдущий день',
            onTap: () =>
                changeDate(selectedDate.subtract(const Duration(days: 1))),
          ),
          SizedBox(width: 10),
          PremiumPressable(
            onTap: pickDate,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined, color: _muted),
                  SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortDate(selectedDate),
                        style: TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        longDate(selectedDate),
                        style: TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 10),
          _SquareButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Следующий день',
            onTap: () => changeDate(selectedDate.add(const Duration(days: 1))),
          ),
          SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: isSameDate(selectedDate, AppState.today)
                ? null
                : () => changeDate(AppState.today),
            icon: Icon(Icons.today_outlined),
            label: const Text('Сегодня'),
          ),
          const Spacer(),
          if (widget.profile.isAdmin) ...[
            OutlinedButton.icon(
              onPressed: sourceForAct.isEmpty ? null : openActPreview,
              icon: Icon(Icons.description_outlined),
              label: const Text('Сформировать акт'),
            ),
            SizedBox(width: 10),
          ],
          FilledButton.icon(
            onPressed: canCreateTask ? openAddTaskScreen : null,
            icon: Icon(Icons.add_rounded),
            label: const Text('Добавить задачу'),
          ),
        ],
      ),
    );
  }

  Widget buildMetrics() {
    final done = tasks.where((task) => task.status == 'Выполнено').length;
    final planned = tasks
        .where((task) => task.status == 'Запланировано')
        .length;
    final other = tasks.length - done - planned;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            icon: Icons.assignment_outlined,
            label: 'Всего задач',
            value: '${tasks.length}',
            detail: cleanObjectName(objectFilter) ?? 'Все объекты',
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            icon: Icons.schedule_rounded,
            label: 'Запланировано',
            value: '$planned',
            detail: 'Ожидают выполнения',
            accent: _planned,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'Выполнено',
            value: '$done',
            detail: '${(progress * 100).round()}% от общего числа',
            accent: _success,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: _MetricCard(
            icon: Icons.construction_rounded,
            label: 'Другой статус',
            value: '$other',
            detail: 'В работе или с замечанием',
            accent: _problem,
          ),
        ),
      ],
    );
  }

  Widget buildFilters() {
    final lockedObject = cleanObjectName(widget.selectedObjectName);
    final objects = objectOptions;

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Поиск по работе, осям, объекту или комментарию...',
                prefixIcon: Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: _input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _line),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _FilterDropdown(
              label: 'Объект',
              value: objectFilter,
              allLabel: 'Все объекты',
              values: objects,
              enabled: lockedObject == null,
              onChanged: (value) => setState(() => objectFilter = value),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _FilterDropdown(
              label: 'Статус',
              value: statusFilter,
              allLabel: 'Все статусы',
              values: statusOptions.skip(1).toList(),
              onChanged: (value) {
                setState(() => statusFilter = value ?? 'Все статусы');
              },
            ),
          ),
          SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: clearFilters,
            icon: Icon(Icons.filter_alt_off_outlined),
            label: const Text('Сбросить'),
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (isLoading && tasks.isEmpty) {
      return _MessageCard(
        icon: Icons.hourglass_top_rounded,
        title: 'Загружаем задачи',
        description: 'Получаем работы за выбранную дату.',
        loading: true,
      );
    }

    if (loadError != null && tasks.isEmpty) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить задачи',
        description: loadError!,
        actionLabel: 'Повторить',
        onAction: () => loadTasks(forceRefresh: true),
      );
    }

    if (tasks.isEmpty) {
      return _MessageCard(
        icon: Icons.assignment_outlined,
        title: 'На эту дату задач нет',
        description: 'Выберите другую дату или добавьте новую задачу.',
      );
    }

    final visible = visibleTasks();
    if (visible.isEmpty) {
      return _MessageCard(
        icon: Icons.search_off_rounded,
        title: 'Задачи не найдены',
        description: 'Измените поиск или сбросьте выбранные фильтры.',
        actionLabel: 'Сбросить фильтры',
        onAction: clearFilters,
      );
    }

    return _TasksTable(tasks: visible, onOpenTask: openTaskDetails);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PremiumWorkBackdrop(
        child: SafeArea(
          child: ListView(
            key: PageStorageKey<String>(
              'desktop-tasks-${widget.selectedObjectName ?? 'all'}',
            ),
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildHeader(),
                      SizedBox(height: 18),
                      buildToolbar(),
                      SizedBox(height: 18),
                      buildMetrics(),
                      SizedBox(height: 18),
                      buildFilters(),
                      SizedBox(height: 18),
                      buildContent(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: _text),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color accent;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.accent = AppAdaptivePalette.telegramBlue,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: _text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
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

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final String allLabel;
  final List<String> values;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.values,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
      ...values.map(
        (item) => DropdownMenuItem<String?>(value: item, child: Text(item)),
      ),
    ];

    final selectedValue = value == allLabel ? null : value;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: _line),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          dropdownColor: _surfaceElevated,
          value: selectedValue,
          isExpanded: true,
          items: items,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

class _TasksTable extends StatelessWidget {
  final List<TaskItemData> tasks;
  final ValueChanged<TaskItemData> onOpenTask;

  const _TasksTable({required this.tasks, required this.onOpenTask});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1320,
            child: Column(
              children: [
                const _TaskTableHeader(),
                ...tasks.map(
                  (task) =>
                      _TaskTableRow(task: task, onTap: () => onOpenTask(task)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTableHeader extends StatelessWidget {
  const _TaskTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      color: _soft,
      child: Row(
        children: [
          SizedBox(width: 150, child: _HeaderText('Статус')),
          SizedBox(width: 410, child: _HeaderText('Работа')),
          SizedBox(width: 190, child: _HeaderText('Оси / участок')),
          SizedBox(width: 190, child: _HeaderText('Объект')),
          Expanded(child: _HeaderText('Комментарий')),
          SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;

  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: _muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _TaskTableRow extends StatelessWidget {
  final TaskItemData task;
  final VoidCallback onTap;

  const _TaskTableRow({required this.task, required this.onTap});

  Color get statusColor {
    switch (task.status) {
      case 'Выполнено':
        return _success;
      case 'Запланировано':
        return _planned;
      default:
        return _problem;
    }
  }

  IconData get statusIcon {
    switch (task.status) {
      case 'Выполнено':
        return Icons.check_rounded;
      case 'Запланировано':
        return Icons.schedule_rounded;
      default:
        return Icons.construction_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final comment = task.notDoneComment.trim();

    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: _surface,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 15, color: statusColor),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          task.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 410,
              child: Text(
                task.work.trim().isEmpty ? 'Работа без названия' : task.work,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
            SizedBox(
              width: 190,
              child: Text(
                task.axes.trim().isEmpty ? 'Не указаны' : task.axes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: 190,
              child: Text(
                task.objectName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _text, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: Text(
                comment.isEmpty ? '—' : comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Icon(Icons.chevron_right_rounded, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  _MessageCard({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 40, color: _muted),
          SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: _text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
