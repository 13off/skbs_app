import 'package:flutter/material.dart';

import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/task_repository.dart';
import '../models/app_user_profile.dart';
import 'employees_screen.dart';
import 'home_screen.dart';
import 'object_management_screen.dart';
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

  /// Какие вкладки уже открывали.
  ///
  /// Вкладка создаётся только при первом открытии и дальше хранит своё состояние.
  final Set<int> _visitedIndexes = <int>{0};

  /// Фоновый прогрев кэша.
  ///
  /// Это не меняет внешний вид приложения. Просто после первого кадра приложение
  /// заранее подгружает основные данные выбранного объекта, чтобы переходы на
  /// вкладки «Сотрудники», «Табель» и «Задачи» ощущались быстрее.
  int _warmUpSerial = 0;
  String? _lastWarmUpObjectKey;

  @override
  void initState() {
    super.initState();

    selectedObjectName = widget.profile.isAdmin
        ? null
        : _cleanObjectName(widget.profile.objectName);

    _scheduleWarmUp();
  }

  String? _cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  String _warmUpKey(String? objectName) {
    return _cleanObjectName(objectName) ?? '__all__';
  }

  void _scheduleWarmUp() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _warmUpCurrentObject();
    });
  }

  Future<void> _warmUpCurrentObject() async {
    final objectName = _cleanObjectName(selectedObjectName);
    final warmUpKey = _warmUpKey(objectName);

    if (_lastWarmUpObjectKey == warmUpKey) return;

    _lastWarmUpObjectKey = warmUpKey;

    final serial = ++_warmUpSerial;
    final today = DateTime.now();

    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchObjectNames(),
        EmployeeRepository.fetchEmployees(objectName: objectName),
        AttendanceRepository.fetchShiftValuesForDate(
          today,
          objectName: objectName,
        ),
        TaskRepository.fetchTasksForDate(today, objectName: objectName),
      ]);
    } catch (_) {
      // Фоновый прогрев не должен мешать работе приложения.
      // Если сеть не ответила — экран сам загрузит данные штатно при открытии.
    }

    if (!mounted || serial != _warmUpSerial) return;
  }

  void changeSelectedObject(String? objectName) {
    if (!widget.profile.isAdmin) return;

    final nextObjectName = _cleanObjectName(objectName);

    if (_cleanObjectName(selectedObjectName) == nextObjectName) return;

    setState(() {
      selectedObjectName = nextObjectName;
    });

    _scheduleWarmUp();
  }

  int get pageCount {
    return widget.profile.isAdmin ? 6 : 4;
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
          return ObjectManagementScreen(
            selectedObjectName: selectedObjectName,
            onObjectChanged: changeSelectedObject,
          );
        case 2:
          return EmployeesScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 3:
          return TimesheetScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 4:
          return TasksScreen(
            profile: widget.profile,
            selectedObjectName: selectedObjectName,
          );
        case 5:
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

  List<NavigationDestination> buildDestinations() {
    if (widget.profile.isAdmin) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Главная',
        ),
        NavigationDestination(
          icon: Icon(Icons.business_outlined),
          selectedIcon: Icon(Icons.business),
          label: 'Объекты',
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

    _visitedIndexes.add(activeIndex);

    final pages = buildPages(activeIndex);
    final destinations = buildDestinations();

    return Scaffold(
      body: IndexedStack(index: activeIndex, children: pages),
      bottomNavigationBar: NavigationBar(
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
