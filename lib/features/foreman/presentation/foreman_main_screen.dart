import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_state.dart';
import '../../../data/task_repository.dart';
import '../../../features/shell/presentation/persistent_tab_shell.dart';
import '../../../features/shell/presentation/premium_main_screen.dart'
    as premium;
import '../../../features/tasks/task_edit_policy.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/task_item_data.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/add_task_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/task_details_screen.dart';
import '../../../widgets/premium_ui.dart';
import 'foreman_desktop_home_screen.dart';
import 'foreman_desktop_tasks_screen.dart';

class ForemanMainScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;
  final AppUserProfile profile;

  const ForemanMainScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = kIsWeb && constraints.maxWidth >= desktopBreakpoint;
        if (!desktop) return premium.MainScreen(profile: profile);
        return _ForemanDesktopMainScreen(profile: profile);
      },
    );
  }
}

class _ForemanDesktopMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const _ForemanDesktopMainScreen({required this.profile});

  @override
  State<_ForemanDesktopMainScreen> createState() =>
      _ForemanDesktopMainScreenState();
}

class _ForemanDesktopMainScreenState extends State<_ForemanDesktopMainScreen> {
  static const int pageCount = 4;
  late final PersistentTabController tabs;

  String? get objectName {
    final value = widget.profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: pageCount);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => ForemanDesktopHomeScreen(
        profile: widget.profile,
        selectedObjectName: objectName,
        onOpenTimesheet: openTimesheet,
        onOpenTasks: openTasks,
        onOpenTask: openTask,
        onAddTask: addTask,
      ),
      1 => ForemanDesktopTasksScreen(
        profile: widget.profile,
        selectedObjectName: objectName,
      ),
      2 => AdaptiveTimesheetScreen(
        profile: widget.profile,
        selectedObjectName: objectName,
      ),
      3 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> select(int index) => tabs.select(index);

  Future<NavigatorState?> selectNavigator(int index) async {
    final navigator = await tabs.selectNavigator(index);
    if (!mounted) return null;
    return navigator;
  }

  Future<void> openTasks() => select(1);
  Future<void> openTimesheet() => select(2);

  Future<void> addTask() async {
    final assignedObject = objectName;
    if (assignedObject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Прорабу не назначен объект')),
      );
      return;
    }
    final date = AppState.today;
    if (!TaskEditPolicy.canCreateForDate(widget.profile, date)) return;
    final navigator = await selectNavigator(1);
    if (navigator == null) return;

    final draft = await navigator.push<TaskCreateDraft>(
      CupertinoPageRoute<TaskCreateDraft>(
        builder: (_) =>
            AddTaskScreen(initialDate: date, objectName: assignedObject),
      ),
    );
    if (draft == null) return;
    await TaskRepository.addTaskWithDetails(
      draft.task,
      objectName: assignedObject,
      assigneeIds: draft.assigneeIds,
      photos: draft.photos,
    );
  }

  Future<void> openTask(TaskItemData task) async {
    final navigator = await selectNavigator(1);
    if (navigator == null) return;
    final result = await navigator.push<dynamic>(
      CupertinoPageRoute<dynamic>(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),
    );
    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
    } else if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'foreman',
      returnToFirstTabOnBack: false,
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Смена',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Задачи',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Табель',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
      tabBuilder: (context, index) => rootPage(index),
    );
  }
}
