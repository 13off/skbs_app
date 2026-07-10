import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/shell/presentation/premium_main_screen.dart' as premium;
import '../models/app_user_profile.dart';
import '../widgets/premium_ui.dart';

class MainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _minimumWarmup = Duration(milliseconds: 1700);
  static const Duration _maximumWarmup = Duration(seconds: 5);

  bool isReady = false;
  int warmupToken = 0;

  @override
  void initState() {
    super.initState();
    warmUpApplication();
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
    final stopwatch = Stopwatch()..start();
    final today = AppState.today;
    final objectName = initialObjectName;

    final dataWarmup = Future.wait<dynamic>([
      ObjectRepository.fetchObjects(),
      EmployeeRepository.fetchEmployees(
        objectName: objectName,
        includeFired: true,
      ),
      AttendanceRepository.fetchShiftValuesForDate(
        today,
        objectName: objectName,
      ),
      TaskRepository.fetchTasksForDate(today, objectName: objectName),
    ]).catchError((_) => <dynamic>[]);

    try {
      await dataWarmup.timeout(_maximumWarmup);
    } catch (_) {
      // При медленном интернете приложение откроется с тем, что уже успело загрузиться.
    }

    final remainingMinimum =
        _minimumWarmup.inMilliseconds - stopwatch.elapsedMilliseconds;

    if (remainingMinimum > 0) {
      await Future<void>.delayed(Duration(milliseconds: remainingMinimum));
    }

    if (!mounted || token != warmupToken) return;

    setState(() {
      isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = animationsDisabled
        ? Duration.zero
        : const Duration(milliseconds: 420);

    return Stack(
      fit: StackFit.expand,
      children: [
        premium.MainScreen(profile: widget.profile),
        IgnorePointer(
          ignoring: isReady,
          child: AnimatedOpacity(
            opacity: isReady ? 0 : 1,
            duration: duration,
            curve: const Cubic(0.22, 1, 0.36, 1),
            child: isReady ? const SizedBox.shrink() : const PremiumLoadingScreen(),
          ),
        ),
      ],
    );
  }
}
