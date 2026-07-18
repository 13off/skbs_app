import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/finance_summary_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/payment_repository.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/task_item_data.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_home_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/payments_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/task_details_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/premium_ui.dart';
import 'manager_reports_screen.dart';

class ManagerMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ManagerMainScreen({super.key, required this.profile});

  @override
  State<ManagerMainScreen> createState() => _ManagerMainScreenState();
}

class _ManagerMainScreenState extends State<ManagerMainScreen>
    with WidgetsBindingObserver {
  static const int pageCount = 5;

  int currentIndex = 0;
  int warmUpToken = 0;
  late final PageController controller;
  late final ValueNotifier<String?> selectedObjectNameNotifier;
  late final List<GlobalKey<NavigatorState>> navigatorKeys;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = PageController();
    selectedObjectNameNotifier = ValueNotifier<String?>(null);
    navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      pageCount,
      (_) => GlobalKey<NavigatorState>(),
    );
    startDataSync();
  }

  @override
  void didUpdateWidget(covariant ManagerMainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);
      startDataSync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AppDataSync.refreshAll();
  }

  @override
  void dispose() {
    warmUpToken++;
    WidgetsBinding.instance.removeObserver(this);
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    controller.dispose();
    selectedObjectNameNotifier.dispose();
    super.dispose();
  }

  void startDataSync() {
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: invalidateCaches,
    );
  }

  void invalidateCaches(Set<AppDataDomain> domains) {
    final objectsChanged = domains.contains(AppDataDomain.objects);
    final employeesChanged =
        objectsChanged || domains.contains(AppDataDomain.employees);
    final attendanceChanged =
        objectsChanged || domains.contains(AppDataDomain.attendance);
    final paymentsChanged =
        objectsChanged || domains.contains(AppDataDomain.payments);
    final tasksChanged = objectsChanged || domains.contains(AppDataDomain.tasks);

    if (objectsChanged) ObjectRepository.clearCache();
    if (employeesChanged) EmployeeRepository.clearCache();
    if (attendanceChanged || paymentsChanged || employeesChanged) {
      AttendanceRepository.clearCache();
      FinanceSummaryRepository.clearCache();
    }
    if (paymentsChanged) PaymentRepository.clearCache();
    if (tasksChanged) TaskRepository.clearTaskListCache();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  void changeSelectedObject(String? objectName) {
    final next = cleanObjectName(objectName);
    if (cleanObjectName(selectedObjectNameNotifier.value) == next) return;
    selectedObjectNameNotifier.value = next;
    unawaited(warmUpVisibleData());
  }

  Future<void> warmUpVisibleData() async {
    final token = ++warmUpToken;
    final objectName = selectedObjectNameNotifier.value;
    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          objectName: objectName,
          includeFired: true,
        ),
        ObjectRepository.fetchObjects(),
      ]).timeout(const Duration(seconds: 7));
    } catch (_) {
      // Рабочие экраны догрузят данные самостоятельно.
    }
    if (!mounted || token != warmUpToken) return;
  }

  Future<void> select(int index) async {
    if (index < 0 || index >= pageCount) return;
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

  Future<void> openEmployees() => select(1);

  Future<void> openReports() => select(2);

  Future<void> openTasks() => select(3);

  Future<void> openTimesheet() async {
    final navigator = await selectNavigator(2);
    if (navigator == null) return;
    await navigator.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => AdaptiveTimesheetScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectNameNotifier.value,
        ),
      ),
    );
  }

  Future<void> openPayments() async {
    final navigator = await selectNavigator(2);
    if (navigator == null) return;
    await navigator.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PaymentsScreen(
          selectedObjectName: selectedObjectNameNotifier.value,
        ),
      ),
    );
  }

  Future<void> openTask(TaskItemData task) async {
    final navigator = await selectNavigator(3);
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

  Widget rootPage(int index, String? selectedObjectName) {
    return switch (index) {
      0 => AdaptiveHomeScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: changeSelectedObject,
          onOpenEmployees: openEmployees,
          onOpenTimesheet: openTimesheet,
          onOpenTasks: openTasks,
          onOpenTask: openTask,
          onOpenPayments: openPayments,
        ),
      1 => AdaptiveEmployeesScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        ),
      2 => ManagerReportsScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: changeSelectedObject,
        ),
      3 => TasksScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        ),
      4 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  Widget tabNavigator(int index) {
    return Navigator(
      key: navigatorKeys[index],
      onGenerateRoute: (settings) => CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) => ValueListenableBuilder<String?>(
          valueListenable: selectedObjectNameNotifier,
          builder: (context, selectedObjectName, _) {
            return rootPage(index, selectedObjectName);
          },
        ),
      ),
    );
  }

  Future<bool> handleBack() async {
    final navigator = navigatorKeys[currentIndex].currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return false;
    }
    if (currentIndex != 0) {
      await select(0);
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
              label: 'Главная',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Люди',
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Отчёты',
              icon: Icons.analytics_outlined,
              selectedIcon: Icons.analytics_rounded,
            ),
            ProfessionalBottomNavigationItem(
              label: 'Задачи',
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment_rounded,
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
