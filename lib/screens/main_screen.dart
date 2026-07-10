import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_theme.dart';
import '../models/app_user_profile.dart';
import '../navigation/web_back_navigation.dart';
import '../widgets/premium_ui.dart';
import 'employees_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';
import 'timesheet_screen.dart';

class MainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  late final ValueNotifier<String?> selectedObjectNameNotifier;
  late final List<GlobalKey<NavigatorState>> navigatorKeys;

  final Set<int> visitedIndexes = <int>{0};

  double dragStartX = 0;
  double dragDistance = 0;

  int get pageCount => widget.profile.isAdmin ? 5 : 4;

  int get safeCurrentIndex {
    if (currentIndex < 0 || currentIndex >= pageCount) return 0;
    return currentIndex;
  }

  bool get supportsAppSwipes {
    return kIsWeb || defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  void initState() {
    super.initState();

    selectedObjectNameNotifier = ValueNotifier<String?>(
      widget.profile.isAdmin ? null : cleanObjectName(widget.profile.objectName),
    );
    navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
      pageCount,
      (_) => GlobalKey<NavigatorState>(),
    );

    setActiveAppBackHandler(handleBackRequest);
  }

  @override
  void dispose() {
    setActiveAppBackHandler(null);
    selectedObjectNameNotifier.dispose();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  void changeSelectedObject(String? objectName) {
    if (!widget.profile.isAdmin) return;

    final nextObjectName = cleanObjectName(objectName);

    if (cleanObjectName(selectedObjectNameNotifier.value) == nextObjectName) {
      return;
    }

    selectedObjectNameNotifier.value = nextObjectName;
  }

  Widget buildRootPage(int index, String? selectedObjectName) {
    if (widget.profile.isAdmin) {
      switch (index) {
        case 0:
          return HomeScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
            onObjectChanged: changeSelectedObject,
          );
        case 1:
          return EmployeesScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 2:
          return TimesheetScreen(
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
        return HomeScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: changeSelectedObject,
        );
      case 1:
        return TasksScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        );
      case 2:
        return TimesheetScreen(
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
    return Navigator(
      key: navigatorKeys[index],
      onGenerateRoute: (settings) {
        return MaterialPageRoute<void>(
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
    );
  }

  List<Widget> buildPages(int activeIndex) {
    return List<Widget>.generate(pageCount, (index) {
      final shouldBuild = visitedIndexes.contains(index) || index == activeIndex;

      if (!shouldBuild) return const SizedBox.shrink();

      return buildTabNavigator(index);
    });
  }

  Widget buildAnimatedPages({
    required int activeIndex,
    required List<Widget> pages,
  }) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.tab;

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: List<Widget>.generate(pages.length, (index) {
          final isActive = index == activeIndex;
          final horizontalOffset = isActive
              ? 0.0
              : index < activeIndex
              ? -0.022
              : 0.022;

          return Positioned.fill(
            child: IgnorePointer(
              ignoring: !isActive,
              child: ExcludeSemantics(
                excluding: !isActive,
                child: AnimatedOpacity(
                  opacity: isActive ? 1 : 0,
                  duration: duration,
                  curve: isActive
                      ? AppMotion.enterCurve
                      : AppMotion.exitCurve,
                  child: AnimatedSlide(
                    offset: Offset(horizontalOffset, 0),
                    duration: duration,
                    curve: AppMotion.emphasizedCurve,
                    child: AnimatedScale(
                      scale: isActive ? 1 : 0.992,
                      duration: duration,
                      curve: AppMotion.enterCurve,
                      child: TickerMode(
                        enabled: isActive,
                        child: RepaintBoundary(child: pages[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
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

  void selectTab(int index) {
    if (index < 0 || index >= pageCount) return;

    if (index == safeCurrentIndex) {
      final navigator = navigatorKeys[index].currentState;

      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      HapticFeedback.selectionClick();
    }

    setState(() {
      currentIndex = index;
      visitedIndexes.add(index);
    });
  }

  Future<bool> handleBackRequest() async {
    final navigator = navigatorKeys[safeCurrentIndex].currentState;

    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }

    if (safeCurrentIndex != 0) {
      selectTab(0);
      return true;
    }

    return false;
  }

  void handleHorizontalDragStart(DragStartDetails details) {
    if (!supportsAppSwipes) return;

    dragStartX = details.globalPosition.dx;
    dragDistance = 0;
  }

  void handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!supportsAppSwipes) return;

    dragDistance += details.primaryDelta ?? 0;
  }

  void handleHorizontalDragEnd(DragEndDetails details) {
    if (!supportsAppSwipes) return;

    final distance = dragDistance;
    dragDistance = 0;

    final navigator = navigatorKeys[safeCurrentIndex].currentState;
    final canPop = navigator?.canPop() ?? false;
    final velocity = details.primaryVelocity ?? 0;
    final isConfidentGesture = distance.abs() >= 72 || velocity.abs() >= 650;

    if (dragStartX <= 34 && distance > 58 && canPop) {
      navigator?.pop();
      return;
    }

    if (canPop || !isConfidentGesture) return;

    if (distance < 0 || velocity < -650) {
      selectTab(mathMin(safeCurrentIndex + 1, pageCount - 1));
      return;
    }

    if (distance > 0 || velocity > 650) {
      selectTab(mathMax(safeCurrentIndex - 1, 0));
    }
  }

  int mathMin(int first, int second) => first < second ? first : second;

  int mathMax(int first, int second) => first > second ? first : second;

  @override
  Widget build(BuildContext context) {
    final activeIndex = safeCurrentIndex;
    visitedIndexes.add(activeIndex);

    final pages = buildPages(activeIndex);
    final tabItems = buildTabItems();

    return WillPopScope(
      onWillPop: () async => !(await handleBackRequest()),
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: handleHorizontalDragStart,
          onHorizontalDragUpdate: handleHorizontalDragUpdate,
          onHorizontalDragEnd: handleHorizontalDragEnd,
          child: buildAnimatedPages(activeIndex: activeIndex, pages: pages),
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
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled ? Duration.zero : AppMotion.regular;

    return Material(
      color: AppColors.background,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 70,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.96),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17191C).withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Row(
                children: List<Widget>.generate(items.length, (index) {
                  final item = items[index];
                  final selected = index == selectedIndex;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: PremiumPressable(
                        onTap: () => onSelected(index),
                        pressedScale: 0.92,
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: duration,
                          curve: AppMotion.springCurve,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.24,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: duration,
                                switchInCurve: AppMotion.springCurve,
                                switchOutCurve: AppMotion.exitCurve,
                                child: Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  key: ValueKey('$index-$selected'),
                                  size: 21,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: duration,
                                curve: AppMotion.enterCurve,
                                style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: selected
                                              ? Colors.white
                                              : AppColors.textMuted,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w650,
                                          fontSize: 10.5,
                                          letterSpacing: -0.2,
                                        ) ??
                                    const TextStyle(),
                                child: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
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
