import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/app_state.dart';
import '../../../data/task_repository.dart';
import '../../../features/developer/data/developer_policy_repository.dart';
import '../../../features/tasks/task_edit_policy.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/task_item_data.dart';
import '../../../screens/add_task_screen.dart';
import '../../../screens/task_details_screen.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/foreman_workspace_repository.dart';
import 'foreman_task_filters.dart';
import 'foreman_task_table.dart';

class ForemanDesktopTasksScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const ForemanDesktopTasksScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<ForemanDesktopTasksScreen> createState() =>
      _ForemanDesktopTasksScreenState();
}

class _ForemanDesktopTasksScreenState extends State<ForemanDesktopTasksScreen> {
  final TextEditingController searchController = TextEditingController();
  DateTime selectedDate = AppState.today;
  List<TaskItemData> tasks = const <TaskItemData>[];
  Map<String, ForemanTaskMeta> meta = const <String, ForemanTaskMeta>{};
  String statusFilter = 'Все статусы';
  String? assigneeFilter;
  bool isLoading = true;
  String? errorText;
  int loadToken = 0;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    loadTasks();
    subscription = AppDataSync.changes.listen((change) {
      if (!mounted ||
          !change.affectsAny(const <AppDataDomain>{
            AppDataDomain.tasks,
            AppDataDomain.objects,
            AppDataDomain.employees,
          })) {
        return;
      }
      loadTasks(silent: true, forceRefresh: true);
    });
  }

  @override
  void didUpdateWidget(covariant ForemanDesktopTasksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      clearFilters();
      loadTasks(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String get objectName =>
      cleanObjectName(widget.selectedObjectName) ??
      cleanObjectName(widget.profile.objectName) ??
      '';

  bool sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  Future<void> loadTasks({
    bool silent = false,
    bool forceRefresh = false,
  }) async {
    final token = ++loadToken;
    if (!silent) {
      setState(() {
        isLoading = true;
        errorText = null;
      });
    }

    try {
      final loaded = await TaskRepository.fetchTasksForDate(
        selectedDate,
        objectName: cleanObjectName(objectName),
        forceRefresh: forceRefresh,
      );
      final loadedMeta = await ForemanWorkspaceRepository.fetchTaskMeta(
        loaded.map((task) => task.id),
      );
      if (!mounted || token != loadToken) return;

      setState(() {
        tasks = loaded;
        meta = loadedMeta;
        isLoading = false;
        errorText = null;
        if (!statusOptions.contains(statusFilter)) {
          statusFilter = 'Все статусы';
        }
        if (assigneeFilter != null &&
            !assigneeOptions.contains(assigneeFilter)) {
          assigneeFilter = null;
        }
      });
    } catch (error) {
      if (!mounted || token != loadToken) return;
      setState(() {
        isLoading = false;
        errorText = error.toString();
      });
    }
  }

  Future<void> refresh() => loadTasks(forceRefresh: true);

  void changeDate(DateTime value) {
    final clean = DateTime(value.year, value.month, value.day);
    if (sameDate(clean, selectedDate)) return;
    setState(() => selectedDate = clean);
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

  bool get canCreateTask {
    return objectName.isNotEmpty &&
        TaskEditPolicy.canCreateForDate(widget.profile, selectedDate);
  }

  Future<void> addTask() async {
    if (objectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прорабу не назначен объект')),
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
          allowAnyDate: TaskEditPolicy.forObject(
            objectName,
          ).foremanCanCreateAnyDate,
        ),
      ),
    );
    if (draft == null) return;

    await TaskRepository.addTaskWithDetails(
      draft.task,
      objectName: objectName,
      assigneeIds: draft.assigneeIds,
      photos: draft.photos,
    );
    if (mounted) await loadTasks(forceRefresh: true);
  }

  Future<void> openTask(TaskItemData task) async {
    final result = await Navigator.push<dynamic>(
      context,
      CupertinoPageRoute<dynamic>(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),
    );
    if (result == null) return;

    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
    } else if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
    }
    if (mounted) await loadTasks(forceRefresh: true);
  }

  ForemanTaskMeta metaFor(TaskItemData task) {
    final id = task.id?.trim();
    return id == null || id.isEmpty
        ? const ForemanTaskMeta()
        : meta[id] ?? const ForemanTaskMeta();
  }

  List<String> get statusOptions {
    final values =
        tasks
            .map((task) => task.status.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return <String>['Все статусы', ...values];
  }

  List<String> get assigneeOptions {
    final values =
        meta.values
            .expand((taskMeta) => taskMeta.assignees)
            .map((assignee) => assignee.employeeName.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<TaskItemData> visibleTasks() {
    final query = searchController.text.trim().toLowerCase();
    final result = tasks.where((task) {
      if (statusFilter != 'Все статусы' && task.status != statusFilter) {
        return false;
      }
      final taskMeta = metaFor(task);
      if (assigneeFilter != null &&
          !taskMeta.assignees.any(
            (item) => item.employeeName.trim() == assigneeFilter,
          )) {
        return false;
      }
      if (query.isEmpty) return true;
      final assignees = taskMeta.assigneeTitle.toLowerCase();
      return task.work.toLowerCase().contains(query) ||
          task.axes.toLowerCase().contains(query) ||
          task.status.toLowerCase().contains(query) ||
          task.notDoneComment.toLowerCase().contains(query) ||
          assignees.contains(query);
    }).toList();

    result.sort((first, second) {
      final firstDone = first.status == 'Выполнено' ? 1 : 0;
      final secondDone = second.status == 'Выполнено' ? 1 : 0;
      final status = firstDone.compareTo(secondDone);
      if (status != 0) return status;
      return first.work.compareTo(second.work);
    });
    return result;
  }

  void clearFilters() {
    setState(() {
      searchController.clear();
      statusFilter = 'Все статусы';
      assigneeFilter = null;
    });
  }

  Widget content() {
    if (isLoading && tasks.isEmpty) {
      return const SpecialistMessageCard(
        icon: Icons.assignment_outlined,
        title: 'Загружаем задачи',
        loading: true,
      );
    }
    if (errorText != null && tasks.isEmpty) {
      return SpecialistMessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить задачи',
        description: errorText,
        actionLabel: 'Повторить',
        onAction: refresh,
      );
    }
    final visible = visibleTasks();
    if (visible.isEmpty) {
      return SpecialistMessageCard(
        icon: Icons.search_off_rounded,
        title: tasks.isEmpty ? 'На эту дату задач нет' : 'Задачи не найдены',
        description: tasks.isEmpty
            ? 'Выберите другую дату или добавьте новую задачу.'
            : 'Измените поиск или сбросьте фильтры.',
        actionLabel: tasks.isEmpty && canCreateTask
            ? 'Добавить задачу'
            : 'Сбросить фильтры',
        onAction: tasks.isEmpty && canCreateTask
            ? addTask
            : () async => clearFilters(),
      );
    }
    return ForemanTaskTable(tasks: visible, meta: meta, onOpenTask: openTask);
  }

  @override
  Widget build(BuildContext context) {
    return SpecialistDesktopPage(
      storageKey: 'desktop-foreman-tasks-$objectName',
      title: 'Задачи объекта',
      subtitle:
          'Работы по датам, статусам и исполнителям с контролем фото и отчётов',
      trailing: IconButton.filledTonal(
        tooltip: 'Обновить задачи',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      onRefresh: refresh,
      children: [
        ForemanTaskToolbar(
          selectedDate: selectedDate,
          onPreviousDay: () =>
              changeDate(selectedDate.subtract(const Duration(days: 1))),
          onNextDay: () =>
              changeDate(selectedDate.add(const Duration(days: 1))),
          onPickDate: pickDate,
          onToday: sameDate(selectedDate, AppState.today)
              ? null
              : () => changeDate(AppState.today),
          onAddTask: canCreateTask ? addTask : null,
        ),
        const SizedBox(height: 18),
        ForemanTaskMetrics(tasks: tasks, meta: meta, objectName: objectName),
        const SizedBox(height: 18),
        ForemanTaskFilters(
          searchController: searchController,
          objectName: objectName,
          status: statusFilter,
          assignee: assigneeFilter,
          statuses: statusOptions.skip(1).toList(),
          assignees: assigneeOptions,
          onSearchChanged: () => setState(() {}),
          onStatusChanged: (value) {
            setState(() => statusFilter = value ?? 'Все статусы');
          },
          onAssigneeChanged: (value) {
            setState(() => assigneeFilter = value);
          },
          onClear: clearFilters,
        ),
        const SizedBox(height: 18),
        content(),
      ],
    );
  }
}
