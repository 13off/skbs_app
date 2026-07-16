import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_data_sync.dart';
import '../data/employee_private_data_repository.dart';
import '../data/employee_private_summary_exporter.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/employee_private_data.dart';
import '../navigation/app_page_route.dart';
import 'add_employee_screen.dart';
import 'desktop_employees_view.dart';
import 'employee_details_screen.dart';
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
  final scrollController = ScrollController();

  List<Employee> employees = const <Employee>[];
  Map<String, EmployeePrivateData> privateDataByEmployeeId =
      const <String, EmployeePrivateData>{};
  bool loading = true;
  String? error;
  int requestId = 0;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  String? get objectName {
    final value = widget.selectedObjectName?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    loadEmployees(showLoading: true);
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant _DesktopEmployeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      loadEmployees(showLoading: true, forceRefresh: true);
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    scrollController.dispose();
    super.dispose();
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted) return;

    if (!change.affectsAny(const <AppDataDomain>{
      AppDataDomain.employees,
      AppDataDomain.objects,
    })) {
      return;
    }

    loadEmployees(forceRefresh: true);
  }

  Future<void> loadEmployees({
    bool showLoading = false,
    bool forceRefresh = false,
  }) async {
    final id = ++requestId;

    if (showLoading && employees.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final loaded = await EmployeeRepository.fetchEmployees(
        objectName: widget.selectedObjectName,
        includeFired: true,
        forceRefresh: forceRefresh,
      );

      var privateMap = <String, EmployeePrivateData>{};
      final employeeIds = loaded
          .map((employee) => employee.id?.trim() ?? '')
          .where((employeeId) => employeeId.isNotEmpty)
          .toSet()
          .toList(growable: false);

      try {
        privateMap = await EmployeePrivateDataRepository.fetchMapByEmployeeIds(
          employeeIds,
        );
      } catch (_) {
        // Таблица остаётся доступной, даже если закрытые данные временно недоступны.
      }

      if (!mounted || id != requestId) return;

      setState(() {
        employees = loaded;
        privateDataByEmployeeId = privateMap;
        loading = false;
        error = null;
      });
    } catch (loadError) {
      if (!mounted || id != requestId) return;

      setState(() {
        loading = false;
        error = loadError.toString();
      });
    }
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
    await loadEmployees();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final position = scrollController.position;
      final target = savedOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > .5) {
        scrollController.jumpTo(target);
      }
    });
  }

  Future<void> addEmployee() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => AddEmployeeScreen(initialObjectName: objectName),
      ),
    );

    if (mounted && saved == true) {
      await loadEmployees(forceRefresh: true);
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
      final source = employees.isNotEmpty
          ? List<Employee>.from(employees)
          : await EmployeeRepository.fetchEmployees(
              objectName: widget.selectedObjectName,
              includeFired: true,
            );
      final ids = source
          .map((employee) => employee.id ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList(growable: false);
      final privateData =
          await EmployeePrivateDataRepository.fetchMapByEmployeeIds(ids);

      await EmployeePrivateSummaryExporter.downloadSummary(
        employees: source,
        privateDataByEmployeeId: privateData,
        objectName: widget.selectedObjectName,
      );

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

  String duplicateKey(Employee employee) {
    final name = employee.name.trim().toLowerCase();
    final phone = employee.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return phone.isNotEmpty
        ? '$name::$phone'
        : '$name::${employee.position.trim().toLowerCase()}';
  }

  List<Employee> preparedEmployees() {
    if (objectName != null) {
      final result = List<Employee>.from(employees);
      result.sort(compareEmployees);
      return result;
    }

    final groups = <String, List<Employee>>{};
    for (final employee in employees) {
      groups.putIfAbsent(duplicateKey(employee), () => <Employee>[]).add(
            employee,
          );
    }

    final result = groups.values.map((group) {
      group.sort(compareEmployees);
      final main = group.first;
      final objects = group
          .map((employee) => employee.objectName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return Employee(
        main.name,
        main.position,
        main.status,
        id: main.id,
        phone: main.phone,
        objectName: objects.isEmpty ? main.objectName : objects.join(', '),
        dailyRate: main.dailyRate,
        isActive: group.any((employee) => employee.isActive),
        comment: main.comment,
      );
    }).toList();

    result.sort(compareEmployees);
    return result;
  }

  int compareEmployees(Employee first, Employee second) {
    if (first.isActive != second.isActive) return first.isActive ? -1 : 1;
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return DesktopEmployeesView(
      profile: widget.profile,
      scopeTitle: objectName ?? 'Все объекты',
      employees: preparedEmployees(),
      privateDataByEmployeeId: privateDataByEmployeeId,
      loading: loading,
      error: error,
      scrollController: scrollController,
      onRefresh: () => loadEmployees(forceRefresh: true),
      onOpenEmployee: openEmployee,
      onOpenPayments: openPayments,
      onDownloadSummary: downloadSummary,
      onAddEmployee: addEmployee,
    );
  }
}
