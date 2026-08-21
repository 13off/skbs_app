import 'package:flutter/material.dart';
import '../navigation/app_page_route.dart';
import 'package:flutter/services.dart';

import '../app/app_adaptive_palette.dart';
import '../data/employee_archive_repository.dart';
import '../data/employee_repository.dart';
import '../features/employee/data/employee_access_repository.dart';
import '../features/employee/presentation/employee_professional_passport_viewer_screen.dart';
import '../features/tasks/presentation/employee_contribution_screen.dart';
import '../features/tools/presentation/company_tools_screen.dart';
import '../features/tools/presentation/document_tool_feature_gate.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import 'add_payment_screen.dart';
import 'edit_employee_screen.dart';
import 'employee_comments_screen.dart';
import 'employee_documents_screen.dart';
import 'employee_private_data_screen.dart';
import 'employee_timesheet_screen.dart';
import 'payment_history_screen.dart';

part 'employee_details/employee_details_access.dart';
part 'employee_details/employee_details_copy.dart';
part 'employee_details/employee_details_formatting.dart';
part 'employee_details/employee_details_navigation.dart';
part 'employee_details/employee_details_sections.dart';
part 'employee_details/employee_details_status.dart';
part 'employee_details/employee_details_view.dart';

class EmployeeDetailsScreen extends StatefulWidget {
  final AppUserProfile profile;
  final Employee employee;

  const EmployeeDetailsScreen({
    super.key,
    required this.profile,
    required this.employee,
  });

  @override
  State<EmployeeDetailsScreen> createState() => _EmployeeDetailsScreenState();
}

class _EmployeeDetailsScreenState extends State<EmployeeDetailsScreen> {
  late Employee employee;
  Future<EmployeeAccessState>? employeeAccessFuture;
  bool isChangingStatus = false;
  bool isCopyingEmployee = false;
  bool isArchivingEmployee = false;
  bool isChangingEmployeeAccess = false;

  void rebuildEmployeeDetails(VoidCallback update) {
    if (!mounted) return;
    setState(update);
  }

  String formatDateTime(DateTime value) {
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}.${twoDigits(value.month)}.${value.year} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  @override
  void initState() {
    super.initState();
    employee = widget.employee;
    refreshEmployeeAccess();
  }

  @override
  Widget build(BuildContext context) => buildEmployeeDetailsView();
}
