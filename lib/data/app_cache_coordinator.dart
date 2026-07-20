import '../features/developer/data/developer_policy_repository.dart';
import '../features/reports/data/manager_reports_repository.dart';
import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'employee_repository.dart';
import 'finance_summary_repository.dart';
import 'object_repository.dart';
import 'payment_repository.dart';
import 'task_repository.dart';

enum AppCacheArea {
  attendance,
  employees,
  financeSummary,
  objects,
  payments,
  tasks,
  developerPolicies,
  managerReports,
}

class AppCacheCoordinator {
  AppCacheCoordinator._();

  static const Set<AppCacheArea> allAreas = <AppCacheArea>{
    AppCacheArea.attendance,
    AppCacheArea.employees,
    AppCacheArea.financeSummary,
    AppCacheArea.objects,
    AppCacheArea.payments,
    AppCacheArea.tasks,
    AppCacheArea.developerPolicies,
    AppCacheArea.managerReports,
  };

  static Set<AppCacheArea> areasFor(Set<AppDataDomain> domains) {
    if (domains.isEmpty) return const <AppCacheArea>{};
    if (domains.contains(AppDataDomain.company)) return allAreas;

    final areas = <AppCacheArea>{};
    final objectsChanged = domains.contains(AppDataDomain.objects);
    final employeesChanged =
        objectsChanged || domains.contains(AppDataDomain.employees);
    final attendanceChanged =
        objectsChanged || domains.contains(AppDataDomain.attendance);
    final paymentsChanged =
        objectsChanged || domains.contains(AppDataDomain.payments);
    final tasksChanged = objectsChanged || domains.contains(AppDataDomain.tasks);

    if (objectsChanged) {
      areas.add(AppCacheArea.objects);
      areas.add(AppCacheArea.developerPolicies);
    }
    if (employeesChanged) areas.add(AppCacheArea.employees);
    if (attendanceChanged || paymentsChanged || employeesChanged) {
      areas.add(AppCacheArea.attendance);
      areas.add(AppCacheArea.financeSummary);
    }
    if (paymentsChanged) areas.add(AppCacheArea.payments);
    if (tasksChanged) areas.add(AppCacheArea.tasks);

    if (domains.any(_affectsManagerReports)) {
      areas.add(AppCacheArea.managerReports);
    }

    return Set<AppCacheArea>.unmodifiable(areas);
  }

  static void invalidate(Set<AppDataDomain> domains) {
    clearAreas(areasFor(domains));
  }

  static void clearAll() {
    clearAreas(allAreas);
  }

  static void clearAreas(Iterable<AppCacheArea> areas) {
    final selected = areas.toSet();
    if (selected.contains(AppCacheArea.attendance)) {
      AttendanceRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.employees)) {
      EmployeeRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.financeSummary)) {
      FinanceSummaryRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.objects)) {
      ObjectRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.payments)) {
      PaymentRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.tasks)) {
      TaskRepository.clearTaskListCache();
    }
    if (selected.contains(AppCacheArea.developerPolicies)) {
      DeveloperPolicyRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.managerReports)) {
      ManagerReportsRepository.clearCache();
    }
  }

  static bool _affectsManagerReports(AppDataDomain domain) {
    return switch (domain) {
      AppDataDomain.attendance ||
      AppDataDomain.payments ||
      AppDataDomain.employees ||
      AppDataDomain.tasks ||
      AppDataDomain.objects ||
      AppDataDomain.notifications ||
      AppDataDomain.company ||
      AppDataDomain.legal ||
      AppDataDomain.recruitment => true,
    };
  }
}
