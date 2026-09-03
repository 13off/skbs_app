import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/app_cache_coordinator.dart';
import '../../../data/app_data_sync.dart';
import '../../../data/app_state.dart';
import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/object_repository.dart';
import '../../../data/task_repository.dart';
import '../../../features/developer/data/developer_policy_repository.dart';
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
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../../navigation/app_page_route.dart';

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
    unawaited(warmUpForemanTaskPolicy());
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      AppDataSync.stop(companyId: oldWidget.profile.activeCompanyId);
      startDataSync();
      unawaited(warmUpForemanTaskPolicy());
      return;
    }

    if (oldWidget.profile.objectName != widget.profile.objectName ||
        oldWidget.profile.actualRole != widget.profile.actualRole) {
      unawaited(warmUpForemanTaskPolicy());
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
      unawaited(warmUpForemanTaskPolicy());
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

  Future<void> warmUpForemanTaskPolicy() async {
    if (!widget.profile.isForeman) return;
    final objectName = cleanObjectName(widget.profile.objectName);
    if (objectName == null) return;
    try {
      await DeveloperPolicyRepository.ensurePolicy(
        objectName,
        forceRefresh: true,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Фоновая синхронизация политики не должна мешать офлайн-работе.
    }
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
      AppPageRoute<void>(
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
      AppPageRoute<dynamic>(
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
          return AppPageRoute<void>(
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

    // A bottom-tab tap must feel immediate. Swiping still uses PageView, but
    // tapping no longer paints two heavyweight workspaces during animation.
    pageController.jumpToPage(index);
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

    // Keep the established nested-navigation and root-route behavior.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: AppSurfaceBackdrop(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: handlePointerDown,
            onPointerUp: handlePointerUp,
            onPointerCancel: (_) => topTapStart = null,
            child: PageView.builder(
              controller: pageController,
              itemCount: pageCount,
              allowImplicitScrolling: false,
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
            storageKey: widget.profile.isAdmin
                ? 'admin'
                : widget.profile.isForeman
                ? 'foreman'
                : 'worker',
            onSelected: selectTab,
          ),
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

class _PremiumBottomBar extends StatelessWidget {
  final List<_TabItem> items;
  final int selectedIndex;
  final String storageKey;
  final ValueChanged<int> onSelected;

  const _PremiumBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.storageKey,
    required this.onSelected,
  });

  static const double _outerHorizontal = 16;
  static const double _innerHorizontal = 8;
  static const double _itemGap = 6;
  static const double _reservedTrailing = 0;
  static const double _contentHeight = 66;
  static const double _contentTop = 7;
  static const double _contentBottom = 7;
  static const double _safeBottomCap = 16;

  static double _safeBottom(BuildContext context) {
    final raw = MediaQuery.paddingOf(context).bottom;
    if (raw <= 0) return 0;
    return raw.clamp(0, _safeBottomCap).toDouble();
  }

  static double totalHeight(BuildContext context) {
    return _contentHeight +
        _contentTop +
        _contentBottom +
        _safeBottom(context);
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = selectedIndex.clamp(0, items.length - 1);
    final totalHeight = _PremiumBottomBar.totalHeight(context);

    return SizedBox(
      height: totalHeight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _outerHorizontal,
          _contentTop,
          _outerHorizontal,
          _contentBottom + _safeBottom(context),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gapTotal = _itemGap * (items.length - 1);
            final freeWidth =
                constraints.maxWidth -
                (_innerHorizontal * 2) -
                gapTotal -
                _reservedTrailing;
            final itemWidth = freeWidth / items.length;

            return Container(
              decoration: BoxDecoration(
                color: AppAdaptivePalette.navigationSurface,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: AppAdaptivePalette.navigationBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: AppAdaptivePalette.isDark ? 0.18 : 0.07,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _innerHorizontal,
                ),
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 210),
                      curve: Curves.easeOutCubic,
                      left: activeIndex * (itemWidth + _itemGap),
                      top: 7,
                      bottom: 7,
                      width: itemWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.navigationSelectedSurface,
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color: AppAdaptivePalette.navigationSelectedBorder,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var index = 0; index < items.length; index++) ...[
                          if (index > 0) const SizedBox(width: _itemGap),
                          SizedBox(
                            width: itemWidth,
                            child: _PremiumTabButton(
                              item: items[index],
                              selected: index == activeIndex,
                              onTap: () => onSelected(index),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PremiumTabButton extends StatelessWidget {
  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  const _PremiumTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? AppAdaptivePalette.navigationSelectedText
        : AppAdaptivePalette.navigationText;
    final iconColor = selected
        ? AppAdaptivePalette.navigationSelectedIcon
        : AppAdaptivePalette.navigationIcon;

    return PremiumPressable(
      semanticLabel: item.label,
      onTap: onTap,
      borderRadius: BorderRadius.circular(21),
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.selectedIcon, size: 24, color: iconColor),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionalPagePhysics extends ScrollPhysics {
  final bool Function() canSwipe;

  const _ConditionalPagePhysics({this.canSwipe, super.parent});

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
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (!canSwipe()) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
