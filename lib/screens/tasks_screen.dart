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

  String get objectTitle {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  void changeDate(DateTime newDate) {
    setState(() {
      selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
    });
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
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
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

    await TaskRepository.addTaskWithDetails(
      draft.task,
      objectName: objectName,
      assigneeIds: draft.assigneeIds,
      photos: draft.photos,
    );

    changeDate(draft.task.date);
  }

  Future<void> openTaskDetails(TaskItemData task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(task: task)),
    );

    if (result == null) return;

    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
      return;
    }

    if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
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
      child: StreamBuilder<List<TaskItemData>>(
        stream: TaskRepository.watchTasksForDate(
          selectedDate,
          objectName: widget.selectedObjectName,
        ),
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final tasks = snapshot.data ?? [];

          return Column(
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

              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Ошибка загрузки задач: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              if (!isLoading && !snapshot.hasError && tasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'На эту дату задач нет',
                    style: TextStyle(fontSize: 16),
                  ),
                ),

              if (!snapshot.hasError)
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
          );
        },
      ),
    );
  }
}
