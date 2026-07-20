import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../navigation/app_page_route.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui.dart';
import 'add_employee_screen.dart';
import 'employee_details_screen.dart';
import 'employees/employee_directory_controller.dart';
import 'payments_screen.dart';

part 'employees/employees_actions.dart';
part 'employees/employees_filtering.dart';
part 'employees/employees_loading.dart';
part 'employees/employees_sections.dart';
part 'employees/employees_view.dart';

const _card = Colors.white;
const _soft = Color(0xFFF2F3F5);
const _line = Color(0xFFE6E8EB);
const _text = Color(0xFF1F2328);
const _accent = Color(0xFF8F9499);

class EmployeesScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const EmployeesScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  late final EmployeeDirectoryController directoryController;

  List<Employee> get employees => directoryController.employees;
  bool get loading => directoryController.loading;
  String? get error => directoryController.error;

  @override
  void initState() {
    super.initState();
    directoryController = EmployeeDirectoryController(
      selectedObjectName: widget.selectedObjectName,
      loadPrivateData: false,
    );
    directoryController.addListener(handleDirectoryChanged);
    directoryController.start();
  }

  @override
  void didUpdateWidget(covariant EmployeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      directoryController.updateObjectName(widget.selectedObjectName);
    }
  }

  void handleDirectoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    directoryController.removeListener(handleDirectoryChanged);
    directoryController.dispose();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildEmployeesView();
}
