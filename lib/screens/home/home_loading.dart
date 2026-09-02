// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../home_screen.dart';

extension _HomeLoading on _HomeScreenState {
  void handleDataChange(AppDataChange change) {
    const dashboardDomains = <AppDataDomain>{
      AppDataDomain.attendance,
      AppDataDomain.payments,
      AppDataDomain.employees,
      AppDataDomain.tasks,
      AppDataDomain.objects,
    };

    if (!mounted || !change.affectsAny(dashboardDomains)) return;
    final refreshObjects = change.affects(AppDataDomain.objects);

    setState(() {
      if (refreshObjects && widget.profile.isAdmin) {
        objectNamesFuture = OfflineObjectRepository.fetchObjectNames();
      }
      dashboardFuture = loadDashboardData();
    });
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;
    return clean;
  }

  String normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String get objectTitle {
    return cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';
  }

  String dateText(DateTime date) {
    const months = <String>[
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  bool isSameObject(String? first, String? second) {
    return cleanObjectName(first) == cleanObjectName(second);
  }

  bool isSameFinancePeriod(FinancePeriod first, FinancePeriod second) {
    return first.year == second.year && first.month == second.month;
  }

  Future<_HomeDashboardData> loadDashboardData({
    bool forceRefresh = false,
  }) async {
    final today = AppState.today;
    final selectedObject = cleanObjectName(widget.selectedObjectName);
    final financeFuture = widget.profile.isAdmin
        ? FinanceSummaryRepository.fetchSummary(
            period: financePeriod,
            objectName: selectedObject,
            forceRefresh: forceRefresh,
          )
        : Future<FinanceSummaryData>.value(FinanceSummaryData.empty);

    final results = await Future.wait<dynamic>([
      OfflineEmployeeRepository.fetchEmployees(
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      OfflineAttendanceRepository.fetchWorkedEmployeeIds(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      financeFuture,
      if (selectedObject == null)
        OfflineObjectRepository.fetchObjectNames(forceRefresh: forceRefresh),
    ]);

    final employees = results[0] as List<Employee>;
    final workedEmployeeIds = results[1] as Set<String>;
    var tasks = results[2] as List<TaskItemData>;

    if (selectedObject == null) {
      final activeObjectNames = (results[4] as List<String>).toSet();
      tasks = tasks
          .where((task) => activeObjectNames.contains(task.objectName.trim()))
          .toList();
    }

    return _HomeDashboardData(
      employees: employees,
      workedEmployeeIds: workedEmployeeIds,
      tasks: tasks,
      finance: results[3] as FinanceSummaryData,
    );
  }

  void refreshObjectsAndDashboard() {
    AppCacheCoordinator.invalidate(const <AppDataDomain>{
      AppDataDomain.objects,
    });

    if (!mounted) return;
    setState(() {
      objectNamesFuture = widget.profile.isAdmin
          ? OfflineObjectRepository.fetchObjectNames(forceRefresh: true)
          : Future<List<String>>.value(const <String>[]);
      dashboardFuture = loadDashboardData(forceRefresh: true);
    });
  }
}
