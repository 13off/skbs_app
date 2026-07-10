import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../models/app_user_profile.dart';
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
  String? selectedObjectName;

  /// Вкладка создаётся только при первом открытии и затем сохраняет состояние.
  ///
  /// Главная уже загружает сотрудников, табель, задачи и финансовую сводку.
  /// Отдельный фоновый прогрев дублировал эти же запросы во время запуска,
  /// поэтому он удалён: данные из репозиториев всё равно попадают в общий кэш.
  final Set<int> _visitedIndexes = <int>{0};

  @override
  void initState() {
    super.initState();

    selectedObjectName = widget.profile.isAdmin
        ? null
        : _cleanObjectName(widget.profile.objectName);
  }

  String? _cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  void changeSelectedObject(String? objectName) {
    if (!widget.profile.isAdmin) return;

    final nextObjectName = _cleanObjectName(objectName);

    if (_cleanObjectName(selectedObjectName) == nextObjectName) return;

    setState(() {
      selectedObjectName = nextObjectName;
    });
  }

  int get pageCount {
    return widget.profile.isAdmin ? 5 : 4;
  }

  int get safeCurrentIndex {
    if (currentIndex < 0) return 0;
    if (currentIndex >= pageCount) return 0;

    return currentIndex;
  }

  Widget _buildPage(int index) {
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

  List<Widget> buildPages(int activeIndex) {
    final pages = <Widget>[];

    for (var index = 0; index < pageCount; index++) {
      final shouldBuildPage =
          _visitedIndexes.contains(index) || index == activeIndex;

      if (shouldBuildPage) {
        pages.add(_buildPage(index));
      } else {
        pages.add(const SizedBox.shrink());
      }
    }

    return pages;
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
              ? -0.018
              : 0.018;

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
                    child: TickerMode(
                      enabled: isActive,
                      child: RepaintBoundary(child: pages[index]),
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

  List<NavigationDestination> buildDestinations() {
    if (widget.profile.isAdmin) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Главная',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Сотрудники',
        ),
        NavigationDestination(
          icon: Icon(Icons.table_chart_outlined),
          selectedIcon: Icon(Icons.table_chart),
          label: 'Табель',
        ),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Задачи',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Профиль',
        ),
      ];
    }

    return const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Главная',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Задачи',
      ),
      NavigationDestination(
        icon: Icon(Icons.table_chart_outlined),
        selectedIcon: Icon(Icons.table_chart),
        label: 'Табель',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Профиль',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = safeCurrentIndex;
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    _visitedIndexes.add(activeIndex);

    final pages = buildPages(activeIndex);
    final destinations = buildDestinations();

    return Scaffold(
      body: buildAnimatedPages(activeIndex: activeIndex, pages: pages),
      bottomNavigationBar: NavigationBar(
        animationDuration: animationsDisabled ? Duration.zero : AppMotion.tab,
        selectedIndex: activeIndex,
        onDestinationSelected: (index) {
          if (index == activeIndex) return;

          setState(() {
            currentIndex = index;
            _visitedIndexes.add(index);
          });
        },
        destinations: destinations,
      ),
    );
  }
}
