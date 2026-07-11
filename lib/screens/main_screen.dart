import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/shell/presentation/premium_main_screen.dart' as premium;
import '../models/app_user_profile.dart';

class MainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _maximumWarmup = Duration(seconds: 7);

  int warmupToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(warmUpApplication());
  }

  @override
  void dispose() {
    warmupToken++;
    super.dispose();
  }

  String? get initialObjectName {
    if (widget.profile.isAdmin) return null;

    final value = widget.profile.objectName.trim();
    if (value.isEmpty) return null;

    return value;
  }

  Future<void> warmUpApplication() async {
    final token = ++warmupToken;
    final today = AppState.today;
    final objectName = initialObjectName;

    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          objectName: objectName,
          includeFired: true,
        ),
        ObjectRepository.fetchObjects(),
        AttendanceRepository.fetchShiftValuesForDate(
          today,
          objectName: objectName,
        ),
        TaskRepository.fetchTasksForDate(today, objectName: objectName),
      ]).timeout(_maximumWarmup);

      if (!mounted || token != warmupToken) return;
    } catch (_) {
      // Остаток данных загрузится обычным фоновым способом внутри экранов.
    }
  }

  @override
  Widget build(BuildContext context) {
    return premium.MainScreen(profile: widget.profile);
  }
}
