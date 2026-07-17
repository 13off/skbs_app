import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_state.dart';
import '../../../data/task_repository.dart';
import '../../../features/milestones/presentation/milestone_home_overlay.dart';
import '../../../features/shell/presentation/premium_main_screen.dart' as premium;
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

class _ForemanDesktopMainScreenState
    extends State<_ForemanDesktopMainScreen> {
  static const int pageCount = 4;
  int currentIndex = 0;
  late final PageController controller;
  late final List<GlobalKey<NavigatorState>> navigatorKeys;

  String? get objectName {
    final value = widget.profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    controller = PageController();
    navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      pageCount,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget rootPage(int index) {
    return switch (index) {
      0 => MilestoneHomeOverlay(
          profile: widget.profile,
          selectedObjectName: objectName,
          child: ForemanDesktopHomeScreen(
            profile: widget.profile,
            selectedObjectName: objectName,
            onOpenTimesheet: openTimesheet,
            onOpenTasks: openTasks,
            onOpenTask: openTask,
            onAddTask: addTask,
          ),
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

  Widget tabNavigator(int index) {
    return Navigator(
      key: navigatorKeys[index],
      onGenerateRoute: (settings) => CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => rootPage(index),
      ),
    );
  }

  Future<void> select(int index) async {
    if (index == currentIndex) {
      final navigator = navigatorKeys[index].currentState;
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }
    await controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<NavigatorState?> selectNavigator(int index) async {
    await select(index);
    if (!mounted) return null;
    await WidgetsBinding.instance.endOfFrame;
    return navigatorKeys[index].currentState;
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
        builder: (_) => AddTaskScreen(
          initialDate: date,
          objectName: assignedObject,
        ),
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

  Future<bool> handleBack() async {
    final navigator = navigatorKeys[currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: handleBack,
      child: Scaffold(
        body: PageView.builder(
          controller: controller,
          itemCount: pageCount,
          allowImplicitScrolling: true,
          onPageChanged: (index) => setState(() => currentIndex = index),
          itemBuilder: (context, index) => tabNavigator(index),
        ),
        bottomNavigationBar: ProfessionalBottomNavigation(
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
          selectedIndex: currentIndex,
          onSelected: select,
        ),
      ),
    );
  }
}
