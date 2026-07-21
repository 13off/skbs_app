import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../data/attendance_repository.dart';
import '../data/timesheet_excel_exporter.dart';
import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';
import 'add_payment_screen.dart';
import 'period_timesheet/period_timesheet_launch_intent.dart';
import 'period_timesheet/period_timesheet_report.dart';

part 'period_timesheet/period_timesheet_export.dart';
part 'period_timesheet/period_timesheet_formatting.dart';
part 'period_timesheet/period_timesheet_loading.dart';
part 'period_timesheet/period_timesheet_period_picker.dart';
part 'period_timesheet/period_timesheet_sections.dart';
part 'period_timesheet/period_timesheet_view.dart';

class PeriodTimesheetScreen extends StatefulWidget {
  final String? selectedObjectName;
  final DateTime? initialMonth;

  const PeriodTimesheetScreen({
    super.key,
    required this.selectedObjectName,
    this.initialMonth,
  });

  @override
  State<PeriodTimesheetScreen> createState() => _PeriodTimesheetScreenState();
}

class _PeriodTimesheetScreenState extends State<PeriodTimesheetScreen> {
  final TextEditingController searchController = TextEditingController();

  late DateTime selectedMonth;
  List<MonthlyTimesheetRow> rows = <MonthlyTimesheetRow>[];
  bool isLoading = false;
  bool isExporting = false;
  bool includeFiredEmployees = false;
  String? errorText;
  int loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    final pendingMonth = PeriodTimesheetLaunchIntent.take();
    final requestedMonth = widget.initialMonth ?? pendingMonth;
    final base = requestedMonth ?? DateTime.now();
    selectedMonth = DateTime(base.year, base.month, 1);
    loadReport();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildPeriodTimesheetView();
}
