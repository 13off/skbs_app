import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../data/task_repository.dart';
import '../models/app_user_profile.dart';
import '../models/task_item_data.dart';
import '../widgets/app_page.dart';
import '../widgets/task_tile.dart';
import 'act_preview_screen.dart';
import 'add_task_screen.dart';
import 'task_details_screen.dart';

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

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  @override
  void didUpdateWidget(covariant TasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (cleanObjectName(oldWidget.selectedObjectName) !=
        cleanObjectName(widget.selectedObjectName)) {
      loadTasks();
    }
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

  Future<void> loadTasks({bool silent = false}) async {
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
      MaterialPageRoute(
        builder: (_) =>
            AddTaskScreen(initialDate: selectedDate, objectName: objectName),
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
        tasks = [...tasks, createdTask];
      });
      return;
    }

    await loadTasks(silent: true);
  }

  Future<void> openTaskDetails(TaskItemData task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task)),
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

  Widget buildDatePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {
              changeDate(selectedDate.subtract(const Duration(days: 1)));
            },
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      shortDate(selectedDate),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      weekDayName(selectedDate),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: () {
              changeDate(selectedDate.add(const Duration(days: 1)));
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget buildTasksCounter(List<TaskItemData> tasks) {
    final doneCount = tasks.where((task) => task.status == 'Выполнено').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, size: 22),
          const SizedBox(width: 10),
          const Text(
            'Задачи:',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            '$doneCount / ${tasks.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              objectTitle,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
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

    return Column(
      children: [
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton.icon(
            onPressed: tasks.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ActPreviewScreen(tasks: tasks, date: selectedDate),
                      ),
                    );
                  },
            icon: const Icon(Icons.description),
            label: const Text('Сформировать акт'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Задачи',
      subtitle: 'Работы по осям за выбранную дату',
      child: Column(
        children: [
          buildDatePanel(),

          const SizedBox(height: 14),

          buildTasksCounter(tasks),

          const SizedBox(height: 14),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(),
            ),

          if (loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Ошибка загрузки задач: $loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),

          if (!isLoading && loadError == null && tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'На эту дату задач нет',
                style: TextStyle(fontSize: 16),
              ),
            ),

          if (loadError == null)
            ...tasks.map((task) {
              return TaskTile(
                task: task,
                onTap: () {
                  openTaskDetails(task);
                },
              );
            }),

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: openAddTaskScreen,
              icon: const Icon(Icons.add),
              label: const Text('Добавить задачу'),
            ),
          ),

          buildActButton(tasks),
        ],
      ),
    );
  }
}
