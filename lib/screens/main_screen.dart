import 'package:flutter/material.dart';

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

    setState(() {
      selectedObjectName = _cleanObjectName(objectName);
    });
  }

  List<Widget> buildPages() {
    if (widget.profile.isAdmin) {
      return [
        HomeScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: changeSelectedObject,
        ),
        EmployeesScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        ),
        TimesheetScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        ),
        TasksScreen(
          profile: widget.profile,
          selectedObjectName: selectedObjectName,
        ),
        ProfileScreen(profile: widget.profile),
      ];
    }

    return [
      HomeScreen(
        profile: widget.profile,
        selectedObjectName: selectedObjectName,
        onObjectChanged: changeSelectedObject,
      ),
      TasksScreen(
        profile: widget.profile,
        selectedObjectName: selectedObjectName,
      ),
      TimesheetScreen(
        profile: widget.profile,
        selectedObjectName: selectedObjectName,
      ),
      ProfileScreen(profile: widget.profile),
    ];
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
    final pages = buildPages();
    final destinations = buildDestinations();

    final safeIndex = currentIndex >= pages.length ? 0 : currentIndex;

    return Scaffold(
      body: pages[safeIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: destinations,
      ),
    );
  }
}
