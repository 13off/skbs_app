import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:intl/intl.dart';

import '../app/app_adaptive_palette.dart';
import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/task_repository.dart';
import '../features/tasks/task_edit_policy.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';
import '../widgets/task_tile.dart';
import 'act_preview_screen.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

Color get _tasksText => AppAdaptivePalette.textPrimary;
Color get _tasksMuted => AppAdaptivePalette.textMuted;
Color get _tasksSoft => AppAdaptivePalette.surfaceSoft;
Color get _tasksLine => AppAdaptivePalette.border;
Color get _tasksAccent => AppAdaptivePalette.accent;

class TasksScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const TasksScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DateTime selectedDate = AppState.today;
  List<TaskItemData> tasks = <TaskItemData>[];
  bool isLoading = true;
  String? loadError;
  int _loadToken = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    loadTasks();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (cleanObjectName(oldWidget.selectedObjectName) !=
        cleanObjectName(widget.selectedObjectName)) {
      loadTasks(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    super.dispose();
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

  String shortDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String weekDayName(DateTime date) {
    const names = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];

    return names[date.weekday - 1];
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  String get objectTitle {
    final objectName = cleanObjectName(widget.selectedObjectName);

    if (objectName == null) {
      return 'Все объекты';
    }

    return objectName;
  }

  bool isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool taskFitsCurrentFilter(TaskItemData task) {
    if (!isSameDate(task.date, selectedDate)) return false;

    final selectedObject = cleanObjectName(widget.selectedObjectName);
    if (selectedObject == null) return true;

    return cleanObjectName(task.objectName) == selectedObject;
  }

  Future<void> loadTasks({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final token = ++_loadToken;

    if (!silent) {
      setState(() {
        isLoading = true;
        loadError = null;
        tasks = <TaskItemData>[];
      });
    }

    try {
      final rows = await TaskRepository.fetchTasksForDate(
        selectedDate,
        objectName: widget.selectedObjectName,
        forceRefresh: forceRefresh,
      );

      if (!mounted || token != _loadToken) return;

      setState(() {
        tasks = rows;
        isLoading = false;
        loadError = null;
      });
    } catch (error) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        isLoading = false;
        loadError = error.toString();
      });
    }
  }

  void changeDate(DateTime newDate) {
    final cleanDate = DateTime(newDate.year, newDate.month, newDate.day);

    if (isSameDate(cleanDate, selectedDate)) return;

    setState(() {
      selectedDate = cleanDate;
    });

    loadTasks();
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;

    changeDate(pickedDate);
  }

  Future<void> openAddTaskScreen() async {
    final objectName = cleanObjectName(widget.selectedObjectName);

    if (objectName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для добавления задачи выберите конкретный объект на Главной',
          ),
        ),
      );
      return;
    }

    final draft = await Navigator.push<TaskCreateDraft>(
      context,
      CupertinoPageRoute(
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
      setState(() {
        selectedDate = draftDate;
      });
      await loadTasks();
      return;
    }

    if (taskFitsCurrentFilter(createdTask)) {
      setState(() {
        tasks = [
          ...tasks.where((task) => task.id != createdTask.id),
          createdTask,
        ];
      });
      return;
    }

    await loadTasks(silent: true);
  }

  Future<void> openTaskDetails(TaskItemData task) async {
    final result = await Navigator.push(
      context,
      CupertinoPageRoute(
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
        final nextTasks = <TaskItemData>[];
        var wasUpdated = false;

        for (final item in tasks) {
          if (item.id == result.id) {
            wasUpdated = true;
            if (taskFitsCurrentFilter(result)) {
              nextTasks.add(result);
            }
          } else {
            nextTasks.add(item);
          }
        }

        if (!wasUpdated && taskFitsCurrentFilter(result)) {
          nextTasks.add(result);
        }

        tasks = nextTasks;
      });
    }
  }

  Widget buildDateArrow({required IconData icon, required VoidCallback onTap}) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _tasksSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _tasksLine),
        ),
        child: Icon(icon, color: _tasksText, size: 24),
      ),
    );
  }

  Widget buildDatePanel() {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          buildDateArrow(
            icon: Icons.chevron_left_rounded,
            onTap: () {
              changeDate(selectedDate.subtract(const Duration(days: 1)));
            },
          ),
          const SizedBox(width: 11),
          Expanded(
            child: PremiumPressable(
              onTap: pickDate,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: _tasksSoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tasksLine),
                ),
                child: Column(
                  children: [
                    Text(
                      shortDate(selectedDate),
                      style: TextStyle(
                        color: _tasksText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weekDayName(selectedDate),
                      style: TextStyle(
                        color: _tasksMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          buildDateArrow(
            icon: Icons.chevron_right_rounded,
            onTap: () {
              changeDate(selectedDate.add(const Duration(days: 1)));
            },
          ),
        ],
      ),
    );
  }

  Widget buildTasksCounter(List<TaskItemData> tasks) {
    final doneCount = tasks.where((task) => task.status == 'Выполнено').length;
    final progress = tasks.isEmpty ? 0.0 : doneCount / tasks.length;

    return PremiumWorkCard(
      radius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _tasksSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _tasksLine),
                ),
                child: Icon(
                  Icons.assignment_turned_in_outlined,
                  color: _tasksText,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ход работ',
                      style: TextStyle(
                        color: _tasksText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      objectTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _tasksMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$doneCount / ${tasks.length}',
                style: TextStyle(
                  color: _tasksText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: _tasksSoft,
              valueColor: AlwaysStoppedAnimation<Color>(_tasksAccent),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            tasks.isEmpty
                ? 'На выбранную дату пока нет задач'
                : 'Выполнено: $doneCount из ${tasks.length}',
            style: TextStyle(
              color: _tasksMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStateCard({
    required IconData icon,
    required String title,
    required String text,
    bool isError = false,
  }) {
    final color = isError ? const Color(0xFF9D3E38) : _tasksMuted;

    return PremiumWorkCard(
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _tasksText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: _tasksMuted,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildActButton(List<TaskItemData> tasks) {
    if (!widget.profile.isAdmin) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: PremiumPressable(
        onTap: tasks.isEmpty
            ? null
            : () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) =>
                        ActPreviewScreen(tasks: tasks, date: selectedDate),
                  ),
                );
              },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: tasks.isEmpty
                ? AppAdaptivePalette.disabledSurface
                : AppAdaptivePalette.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tasksLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                color: tasks.isEmpty
                    ? AppAdaptivePalette.disabledText
                    : _tasksText,
                size: 20,
              ),
              SizedBox(width: 9),
              Text(
                'Сформировать акт',
                style: TextStyle(
                  color: tasks.isEmpty
                      ? AppAdaptivePalette.disabledText
                      : _tasksText,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leading = <Widget>[
      buildDatePanel(),
      const SizedBox(height: 14),
      buildTasksCounter(tasks),
      const SizedBox(height: 14),
      if (isLoading)
        const PremiumWorkCard(
          radius: 24,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      if (loadError != null)
        buildStateCard(
          icon: Icons.error_outline_rounded,
          title: 'Не удалось загрузить задачи',
          text: loadError!,
          isError: true,
        ),
      if (!isLoading && loadError == null && tasks.isEmpty)
        buildStateCard(
          icon: Icons.assignment_outlined,
          title: 'Задач пока нет',
          text: 'Добавьте первую задачу на выбранную дату и объект.',
        ),
    ];

    return AppLazyPage(
      title: 'Задачи',
      subtitle: 'Работы по осям, исполнители и готовность за выбранную дату',
      leading: leading,
      itemCount: loadError == null ? tasks.length : 0,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskTile(task: task, onTap: () => openTaskDetails(task));
      },
      trailing: <Widget>[
        const SizedBox(height: 14),
        PremiumActionButton(
          label: 'Добавить задачу',
          icon: Icons.add_rounded,
          onPressed:
              TaskEditPolicy.canCreateForDate(widget.profile, selectedDate)
              ? openAddTaskScreen
              : null,
        ),
        buildActButton(tasks),
      ],
    );
  }
}
