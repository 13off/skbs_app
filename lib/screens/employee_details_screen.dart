import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

import '../data/employee_archive_repository.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import 'add_payment_screen.dart';
import 'edit_employee_screen.dart';
import 'employee_comments_screen.dart';
import 'employee_documents_screen.dart';
import 'employee_private_data_screen.dart';
import 'employee_timesheet_screen.dart';
import 'payment_history_screen.dart';

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
  bool isChangingStatus = false;
  bool isCopyingEmployee = false;
  bool isArchivingEmployee = false;

  @override
  void initState() {
    super.initState();
    employee = widget.employee;
  }

  @override
  Widget build(BuildContext context) => buildEmployeeDetailsView();
}
