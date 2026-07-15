import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/legal/presentation/legal_main_screen.dart';
import '../features/shell/presentation/premium_main_screen.dart' as premium;
import '../models/app_user_profile.dart';
import 'profile_screen.dart';

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
    if (widget.profile.isAdmin || widget.profile.isForeman) {
      unawaited(warmUpApplication());
    }
  }

  @override
  void dispose() {
    warmupToken++;
    super.dispose();
  }

  String? get initialObjectName {
    if (widget.profile.isAdmin) return null;
    final value = widget.profile.objectName.trim();
    return value.isEmpty ? null : value;
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
      // Остаток данных загрузится внутри экранов.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.profile.isLawyer) {
      return LegalMainScreen(profile: widget.profile);
    }
    if (widget.profile.isAccountant) {
      return Scaffold(body: ProfileScreen(profile: widget.profile));
    }
    return premium.MainScreen(profile: widget.profile);
  }
}
