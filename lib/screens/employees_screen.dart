import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
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

Color get _card => AppAdaptivePalette.inputSurface;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _line => AppAdaptivePalette.border;
Color get _text => AppAdaptivePalette.textPrimary;
Color get _accent => AppAdaptivePalette.accent;

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
