import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/payment_repository.dart';
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
  static const Duration _maximumWarmup = Duration(seconds: 9);

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

    final value = widget.profile.objectName?.trim();
    if (value == null || value.isEmpty) return null;

    return value;
  }

  Future<void> warmUpApplication() async {
    final token = ++warmupToken;
    final today = AppState.today;
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final objectName = initialObjectName;

    try {
      final employees = await EmployeeRepository.fetchEmployees(
        objectName: objectName,
        includeFired: true,
      ).timeout(_maximumWarmup);

      if (!mounted || token != warmupToken) return;

      final employeeIds = employees
          .map((employee) => employee.id ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList();

      await Future.wait<dynamic>([
        ObjectRepository.fetchObjects(),
        AttendanceRepository.fetchShiftValuesForDate(
          yesterday,
          objectName: objectName,
        ),
        AttendanceRepository.fetchShiftValuesForDate(
          today,
          objectName: objectName,
        ),
        AttendanceRepository.fetchShiftValuesForDate(
          tomorrow,
          objectName: objectName,
        ),
        TaskRepository.fetchTasksForDate(yesterday, objectName: objectName),
        TaskRepository.fetchTasksForDate(today, objectName: objectName),
        TaskRepository.fetchTasksForDate(tomorrow, objectName: objectName),
        PaymentRepository.fetchPaymentsForEmployees(employeeIds),
      ]).timeout(_maximumWarmup);
    } catch (_) {
      // Остаток данных загрузится обычным фоновым способом внутри экранов.
    }
  }

  @override
  Widget build(BuildContext context) {
    return premium.MainScreen(profile: widget.profile);
  }
}
