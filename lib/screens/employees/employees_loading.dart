part of '../employees_screen.dart';

extension _EmployeesLoading on _EmployeesScreenState {
  String? get objectName {
    final value = widget.selectedObjectName?.trim();
    return value == null || value.isEmpty ? null : value;
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
      if (!mounted || id != requestId) return;
      setState(() {
        employees = loaded;
        loading = false;
        error = null;
      });
    } catch (exception) {
      if (!mounted || id != requestId) return;
      setState(() {
        loading = false;
        error = exception.toString();
      });
    }
  }
}
