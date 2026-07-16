import '../../../models/employee.dart';
import '../../../models/task_item_data.dart';
import '../data/foreman_workspace_repository.dart';

class ForemanDashboardData {
  final List<Employee> employees;
  final Map<String, double> shifts;
  final List<TaskItemData> todayTasks;
  final List<TaskItemData> overdueTasks;
  final Map<String, ForemanTaskMeta> meta;

  const ForemanDashboardData({
    required this.employees,
    required this.shifts,
    required this.todayTasks,
    required this.overdueTasks,
    required this.meta,
  });

  ForemanTaskMeta metaFor(TaskItemData task) {
    final id = task.id?.trim();
    if (id == null || id.isEmpty) return const ForemanTaskMeta();
    return meta[id] ?? const ForemanTaskMeta();
  }
}
