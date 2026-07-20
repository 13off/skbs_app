import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';

import '../../../app/app_theme.dart';
import '../../../data/app_cache_coordinator.dart';
import '../../../data/app_data_sync.dart';
import '../../../data/app_state.dart';
import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/task_item_data.dart';
import '../../../navigation/web_back_navigation.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_home_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/payments_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/task_details_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/premium_ui.dart';

class MainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int currentIndex = 0;
  int warmUpToken = 0;

  late final ValueNotifier<String?> selectedObjectNameNotifier;
  late final List<GlobalKey<NavigatorState>> navigatorKeys;
  late final PageController pageController;

  Offset? topTapStart;

  int get pageCount => widget.profile.isAdmin ? 5 : 4;

  int get safeCurrentIndex {
    if (currentIndex < 0 || currentIndex >= pageCount) return 0;
    return currentIndex;
  }

  int get tasksTabIndex => widget.profile.isAdmin ? 3 : 1;

  int get timesheetTabIndex => 2;

  bool get supportsAppSwipes {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    selectedObjectNameNotifier = ValueNotifier<String?>(
      widget.profile.isAdmin
          ? null
          : cleanObjectName(widget.profile.objectName),
    );
    navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      pageCount,
      (_) => GlobalKey<NavigatorState>(),
    );
    pageController = PageController(initialPage: currentIndex);

    setActiveAppBackHandler(handleBackRequest);
    startDataSync();
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);
      startDataSync();
    }
  }

  @override
  void dispose() {
    warmUpToken++;
    WidgetsBinding.instance.removeObserver(this);
    setActiveAppBackHandler(null);
    AppDataSync.stop(companyId: widget.profile.activeCompanyId);
    pageController.dispose();
    selectedObjectNameNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppDataSync.refreshAll();
    }
  }

  void startDataSync() {
    AppDataSync.start(
      companyId: widget.profile.activeCompanyId,
      invalidateCaches: AppCacheCoordinator.invalidate,
    );
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  Future<void> warmUpVisibleData() async {
    final token = ++warmUpToken;

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted || token != warmUpToken) return;

    final objectName = selectedObjectNameNotifier.value;
    final today = AppState.today;

    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          objectName: objectName,
          includeFired: true,
        ),
        AttendanceRepository.fetchShiftValuesForDate(
          today,
          objectName: objectName,
        ),
        TaskRepository.fetchTasksForDate(today, objectName: objectName),
        ObjectRepository.fetchObjects(),
      ]).timeout(const Duration(seconds: 7));
    } catch (_) {
      // Фоновый прогрев не должен мешать работе приложения.
    }
  }

  void changeSelectedObject(String? objectName) {
    if (!widget.profile.isAdmin) return;

    final nextObjectName = cleanObjectName(objectName);

    if (cleanObjectName(selectedObjectNameNotifier.value) == nextObjectName) {
      return;
    }

    selectedObjectNameNotifier.value = nextObjectName;
    warmUpVisibleData();
  }

  Future<void> openEmployeesFromHome() async {
    if (!widget.profile.isAdmin) {
      await selectTab(timesheetTabIndex);
      return;
    }

    await selectTab(1);
  }

  Future<void> openTimesheetFromHome() async {
    await selectTab(timesheetTabIndex);
  }

  Future<void> openTasksFromHome() async {
    await selectTab(tasksTabIndex);
  }

  Future<NavigatorState?> selectTabNavigator(int index) async {
    await selectTab(index);

    if (!mounted) return null;

    await WidgetsBinding.instance.endOfFrame;

    return navigatorKeys[index].currentState;
  }

  Future<void> openPaymentsFromHome() async {
    if (!widget.profile.isAdmin) return;

    final navigator = await selectTabNavigator(1);
    if (navigator == null) return;

    await navigator.push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PaymentsScreen(
          selectedObjectName: selectedObjectNameNotifier.value,
        ),
      ),
    );
  }

  Future<void> openTaskFromHome(TaskItemData task) async {
    final navigator = await selectTabNavigator(tasksTabIndex);
    if (navigator == null) return;

    final result = await navigator.push<dynamic>(
      CupertinoPageRoute<dynamic>(
        builder: (_) => TaskDetailsScreen(task: task, profile: widget.profile),
      ),
    );

    if (result == 'delete') {
      await TaskRepository.deleteTask(task);
      return;
    }

    if (result is TaskItemData) {
      await TaskRepository.updateTask(result);
    }
  }

  Widget buildRootPage(int index, String? selectedObjectName) {
    if (widget.profile.isAdmin) {
      switch (index) {
        case 0:
          return AdaptiveHomeScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
            onObjectChanged: changeSelectedObject,
            onOpenEmployees: openEmployeesFromHome,
            onOpenTimesheet: openTimesheetFromHome,
            onOpenTasks: openTasksFromHome,
            onOpenTask: openTaskFromHome,
            onOpenPayments: openPaymentsFromHome,
          );
        case 1:
          return AdaptiveEmployeesScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 2:
          return AdaptiveTimesheetScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 3:
          return TasksScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 4:
          return ProfileScreen(profile: widget.profile);
        default:
          return const SizedBox.shrink();
      }
    }

    switch (index) {
      case 0:
        return AdaptiveHomeScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: changeSelectedObject,
          onOpenEmployees: openEmployeesFromHome,
          onOpenTimesheet: openTimesheetFromHome,
          onOpenTasks: openTasksFromHome,
          onOpenTask: openTaskFromHome,
          onOpenPayments: openPaymentsFromHome,
        );
      case 1:
        return TasksScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        );
      case 2:
        return AdaptiveTimesheetScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        );
      case 3:
        return ProfileScreen(profile: widget.profile);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget buildTabNavigator(int index) {
    return _KeepAliveTab(
      key: ValueKey<String>('tab-$index'),
      child: Navigator(
        key: navigatorKeys[index],
        onGenerateRoute: (settings) {
          return CupertinoPageRoute<void>(
            settings: settings,
            builder: (_) {
              return ValueListenableBuilder<String?>(
                valueListenable: selectedObjectNameNotifier,
                builder: (context, selectedObjectName, _) {
                  return buildRootPage(index, selectedObjectName);
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_TabItem> buildTabItems() {
    if (widget.profile.isAdmin) {
      return const [
        _TabItem(
          label: 'Главная',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
        ),
        _TabItem(
          label: 'Люди',
          icon: Icons.groups_outlined,
          selectedIcon: Icons.groups_rounded,
        ),
        _TabItem(
          label: 'Табель',
          icon: Icons.calendar_today_outlined,
          selectedIcon: Icons.calendar_month_rounded,
        ),
        _TabItem(
          label: 'Задачи',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
        ),
        _TabItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ];
    }

    return const [
      _TabItem(
        label: 'Главная',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _TabItem(
        label: 'Задачи',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
      ),
      _TabItem(
        label: 'Табель',
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_month_rounded,
      ),
      _TabItem(
        label: 'Профиль',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];
  }

  bool canSwipeBetweenTabs() {
    final navigator = navigatorKeys[safeCurrentIndex].currentState;
    return navigator == null || !navigator.canPop();
  }

  Future<void> selectTab(int index) async {
    if (index < 0 || index >= pageCount) return;

    if (index == safeCurrentIndex) {
      final navigator = navigatorKeys[index].currentState;

      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      } else {
        scrollActiveRouteToTop();
      }
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }

    await pageController.animateToPage(
      index,
      duration: AppMotion.tab,
      curve: AppMotion.enterCurve,
    );
  }

  void handlePageChanged(int index) {
    if (!mounted || currentIndex == index) return;

    setState(() {
      currentIndex = index;
    });
  }

  Future<bool> handleBackRequest() async {
    final navigator = navigatorKeys[safeCurrentIndex].currentState;

    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }

    if (safeCurrentIndex != 0) {
      await selectTab(0);
      return true;
    }

    return false;
  }

  void handlePointerDown(PointerDownEvent event) {
    final paddingTop = MediaQuery.paddingOf(context).top;

    topTapStart = paddingTop > 0 && event.position.dy <= paddingTop
        ? event.position
        : null;
  }

  void handlePointerUp(PointerUpEvent event) {
    final start = topTapStart;
    topTapStart = null;

    if (start == null) return;

    final movement = (event.position - start).distance;
    if (movement > 12) return;

    scrollActiveRouteToTop();
  }

  void scrollActiveRouteToTop() {
    final rootContext = navigatorKeys[safeCurrentIndex].currentContext;

    if (rootContext is! Element) return;

    final candidates = <ScrollableState>[];

    void visit(Element element, bool hidden) {
      final widget = element.widget;
      var nextHidden = hidden;

      if (widget is Offstage && widget.offstage) {
        nextHidden = true;
      }
      if (widget is Visibility && !widget.visible) {
        nextHidden = true;
      }

      if (!nextHidden &&
          element is StatefulElement &&
          element.state is ScrollableState) {
        final state = element.state as ScrollableState;

        try {
          final position = state.position;
          final isVertical =
              axisDirectionToAxis(position.axisDirection) == Axis.vertical;

          if (isVertical && position.hasPixels && position.pixels > 0.5) {
            candidates.add(state);
          }
        } catch (_) {
          // Scrollable ещё не успел прикрепиться к позиции.
        }
      }

      element.visitChildren((child) => visit(child, nextHidden));
    }

    visit(rootContext, false);

    if (candidates.isEmpty) return;

    candidates.sort((first, second) {
      return second.position.pixels.compareTo(first.position.pixels);
    });

    final position = candidates.first.position;

    position.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = safeCurrentIndex;
    final tabItems = buildTabItems();

    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: Scaffold(
        body: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: handlePointerDown,
          onPointerUp: handlePointerUp,
          onPointerCancel: (_) => topTapStart = null,
          child: PageView.builder(
            controller: pageController,
            itemCount: pageCount,
            allowImplicitScrolling: true,
            physics: supportsAppSwipes
                ? _ConditionalPagePhysics(canSwipe: canSwipeBetweenTabs)
                : const NeverScrollableScrollPhysics(),
            onPageChanged: handlePageChanged,
            itemBuilder: (context, index) {
              return buildTabNavigator(index);
            },
          ),
        ),
        bottomNavigationBar: _PremiumBottomBar(
          items: tabItems,
          selectedIndex: activeIndex,
          onSelected: selectTab,
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({super.key, required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin<_KeepAliveTab> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}

class _ConditionalPagePhysics extends PageScrollPhysics {
  final bool Function() canSwipe;

  const _ConditionalPagePhysics({required this.canSwipe, super.parent});

  @override
  _ConditionalPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _ConditionalPagePhysics(
      canSwipe: canSwipe,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    return canSwipe() && super.shouldAcceptUserOffset(position);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (!canSwipe()) return 0;
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

class _PremiumBottomBar extends StatelessWidget {
  final List<_TabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _PremiumBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ProfessionalBottomNavigation(
      items: items
          .map(
            (item) => ProfessionalBottomNavigationItem(
              label: item.label,
              icon: item.icon,
              selectedIcon: item.selectedIcon,
            ),
          )
          .toList(growable: false),
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
