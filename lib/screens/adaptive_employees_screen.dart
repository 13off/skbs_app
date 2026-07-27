import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../navigation/app_page_route.dart';
import 'add_employee_screen.dart';
import 'desktop_employees_view.dart';
import 'employee_details_screen.dart';
import 'employees/employee_directory_controller.dart';
import 'employees_screen.dart';
import 'payments_screen.dart';

class AdaptiveEmployeesScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;

  const AdaptiveEmployeesScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopTable =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;

        if (!useDesktopTable) {
          return EmployeesScreen(
            profile: profile,
            selectedObjectName: selectedObjectName,
          );
        }

        return _DesktopEmployeesScreen(
          profile: profile,
          selectedObjectName: selectedObjectName,
        );
      },
    );
  }
}

class _DesktopEmployeesScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const _DesktopEmployeesScreen({
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<_DesktopEmployeesScreen> createState() =>
      _DesktopEmployeesScreenState();
}

class _DesktopEmployeesScreenState extends State<_DesktopEmployeesScreen> {
  final ScrollController scrollController = ScrollController();
  late final EmployeeDirectoryController directoryController;

  @override
  void initState() {
    super.initState();
    directoryController = EmployeeDirectoryController(
      selectedObjectName: widget.selectedObjectName,
      loadPrivateData: true,
    );
    directoryController.addListener(handleDirectoryChanged);
    directoryController.start();
  }

  @override
  void didUpdateWidget(covariant _DesktopEmployeesScreen oldWidget) {
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
    scrollController.dispose();
    super.dispose();
  }

  Future<void> openEmployee(Employee employee) async {
    final savedOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;

    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeDetailsScreen(
          profile: widget.profile,
          employee: employee,
        ),
      ),
    );

    if (!mounted) return;
    await directoryController.load();
    if (!mounted) return;
    EmployeeDirectoryLogic.restoreScrollOffset(scrollController, savedOffset);
  }

  Future<void> addEmployee() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => AddEmployeeScreen(
          initialObjectName: directoryController.objectName,
        ),
      ),
    );

    if (mounted && saved == true) {
      await directoryController.load(forceRefresh: true);
    }
  }

  void openPayments() {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => PaymentsScreen(
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  Future<void> downloadSummary() async {
    try {
      await directoryController.downloadSummary();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сводка скачана')),
        );
      }
    } catch (summaryError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка формирования сводки: $summaryError'),
          ),
        );
      }
    }
  }

  Employee prepareForDesktopDirectory(Employee employee) {
    return Employee(
      employee.name,
      employee.positionTitle,
      employee.status,
      id: employee.id,
      personId: employee.personId,
      objectId: employee.objectId,
      phone: employee.phone,
      objectName: employee.objectName,
      dailyRate: employee.dailyRate,
      isActive: employee.isActive,
      comment: employee.comment,
    );
  }

  List<Employee> preparedEmployees() {
    return directoryController
        .preparedEmployees(
          sortSelectedObject: true,
          sortDuplicateGroupsByObject: false,
          caseInsensitiveNameSort: true,
        )
        .map(prepareForDesktopDirectory)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return DesktopEmployeesView(
      profile: widget.profile,
      scopeTitle: directoryController.objectName ?? 'Все объекты',
      employees: preparedEmployees(),
      privateDataByEmployeeId: directoryController.privateDataByEmployeeId,
      loading: directoryController.loading,
      error: directoryController.error,
      scrollController: scrollController,
      onRefresh: () => directoryController.load(forceRefresh: true),
      onOpenEmployee: openEmployee,
      onOpenPayments: openPayments,
      onDownloadSummary: downloadSummary,
      onAddEmployee: addEmployee,
    );
  }
}
