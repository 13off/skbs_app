import '../features/developer/data/developer_policy_repository.dart';
import '../features/employee/data/employee_task_cabinet_repository.dart';
import '../features/reports/data/manager_reports_repository.dart';
import '../features/reports/data/manager_weekly_contribution_repository.dart';
import '../features/timesheet/data/timesheet_group_repository.dart';
import 'app_data_sync.dart';
import 'attendance_repository.dart';
import 'employee_archive_repository.dart';
import 'employee_private_data_repository.dart';
import 'employee_repository.dart';
import 'finance_summary_repository.dart';
import 'notification_repository.dart';
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
  notifications,
  developerPolicies,
  managerReports,
  managerWeeklyContribution,
  timesheetGroups,
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
    AppCacheArea.notifications,
    AppCacheArea.developerPolicies,
    AppCacheArea.managerReports,
    AppCacheArea.managerWeeklyContribution,
    AppCacheArea.timesheetGroups,
  };

  static const Set<AppDataDomain> _managerReportDomains = <AppDataDomain>{
    AppDataDomain.attendance,
    AppDataDomain.payments,
    AppDataDomain.employees,
    AppDataDomain.tasks,
    AppDataDomain.objects,
    AppDataDomain.notifications,
    AppDataDomain.company,
    AppDataDomain.legal,
    AppDataDomain.recruitment,
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
    final tasksChanged =
        objectsChanged || domains.contains(AppDataDomain.tasks);

    if (objectsChanged) {
      areas.add(AppCacheArea.objects);
      areas.add(AppCacheArea.developerPolicies);
    }
    if (employeesChanged) {
      areas.add(AppCacheArea.employees);
      areas.add(AppCacheArea.timesheetGroups);
    }
    if (attendanceChanged || paymentsChanged || employeesChanged) {
      areas.add(AppCacheArea.attendance);
      areas.add(AppCacheArea.financeSummary);
    }
    if (paymentsChanged) areas.add(AppCacheArea.payments);
    if (tasksChanged) areas.add(AppCacheArea.tasks);
    if (domains.contains(AppDataDomain.notifications)) {
      areas.add(AppCacheArea.notifications);
    }

    if (domains.any(_managerReportDomains.contains)) {
      areas.add(AppCacheArea.managerReports);
      areas.add(AppCacheArea.managerWeeklyContribution);
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
    if (selected.isEmpty) return;

    final clearEmployeeCabinet =
        selected.contains(AppCacheArea.employees) ||
        selected.contains(AppCacheArea.tasks);

    if (selected.contains(AppCacheArea.attendance)) {
      AttendanceRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.employees)) {
      EmployeeRepository.clearCache();
      EmployeePrivateDataRepository.clearCache();
      EmployeeArchiveRepository.clearCache();
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
    if (selected.contains(AppCacheArea.notifications)) {
      NotificationRepository.clearCache();
    }
    if (clearEmployeeCabinet) {
      EmployeeTaskCabinetRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.developerPolicies)) {
      DeveloperPolicyRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.managerReports)) {
      ManagerReportsRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.managerWeeklyContribution)) {
      ManagerWeeklyContributionRepository.clearCache();
    }
    if (selected.contains(AppCacheArea.timesheetGroups)) {
      TimesheetGroupRepository.clearCache();
    }
  }
}
