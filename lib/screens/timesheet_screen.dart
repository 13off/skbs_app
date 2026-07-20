import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app/app_theme.dart';
import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../features/timesheet/models/timesheet_draft.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui.dart';
import 'period_timesheet_screen.dart';

part 'timesheet/timesheet_actions.dart';
part 'timesheet/timesheet_loading.dart';
part 'timesheet/timesheet_sections.dart';
part 'timesheet/timesheet_sync.dart';
part 'timesheet/timesheet_view.dart';

class TimesheetScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const TimesheetScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  DateTime selectedDate = AppState.today;
  Future<List<Employee>>? employeesFuture;
  TimesheetDraft timesheetDraft = TimesheetDraft.empty();

  bool isAttendanceLoading = false;
  bool isSaving = false;
  String? errorText;
  bool hasPendingRemoteAttendance = false;
  int attendanceLoadGeneration = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  final TextEditingController searchController = TextEditingController();

  final List<double> quickShiftOptions = const <double>[0, 0.5, 1, 1.5, 2];

  bool get hasUnsavedChanges => timesheetDraft.hasChanges;

  List<double> get allShiftOptions {
    return List<double>.generate(31, (index) => index / 10);
  }

  @override
  void initState() {
    super.initState();
    reloadEmployees();
    loadAttendance();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant TimesheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      reloadEmployees(forceRefresh: true);
      loadAttendance(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildTimesheetView();
}
