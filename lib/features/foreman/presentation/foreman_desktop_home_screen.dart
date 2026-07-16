import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/app_state.dart';
import '../../../data/attendance_repository.dart';
import '../../../data/employee_repository.dart';
import '../../../data/task_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../models/task_item_data.dart';
import '../../../widgets/notification_bell.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/foreman_workspace_repository.dart';
import 'foreman_attendance_control.dart';
import 'foreman_home_summary_widgets.dart';
import 'foreman_task_control.dart';
import 'foreman_workspace_models.dart';

class ForemanDesktopHomeScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final Future<void> Function() onOpenTimesheet;
  final Future<void> Function() onOpenTasks;
  final Future<void> Function(TaskItemData task) onOpenTask;
  final Future<void> Function() onAddTask;

  const ForemanDesktopHomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onOpenTimesheet,
    required this.onOpenTasks,
    required this.onOpenTask,
    required this.onAddTask,
  });

  @override
  State<ForemanDesktopHomeScreen> createState() =>
      _ForemanDesktopHomeScreenState();
}

class _ForemanDesktopHomeScreenState
    extends State<ForemanDesktopHomeScreen> {
  late Future<ForemanDashboardData> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (!mounted ||
          !change.affectsAny(const <AppDataDomain>{
            AppDataDomain.attendance,
            AppDataDomain.employees,
            AppDataDomain.objects,
            AppDataDomain.tasks,
          })) {
        return;
      }
      refresh();
    });
  }

  @override
  void didUpdateWidget(covariant ForemanDesktopHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      setState(() => future = load(forceRefresh: true));
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String get objectName =>
      cleanObjectName(widget.selectedObjectName) ??
      cleanObjectName(widget.profile.objectName) ??
      '';

  Future<ForemanDashboardData> load({bool forceRefresh = false}) async {
    final today = AppState.today;
    final object = cleanObjectName(objectName);
    final results = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: object,
        forceRefresh: forceRefresh,
      ),
      AttendanceRepository.fetchShiftValuesForDate(
        today,
        objectName: object,
        forceRefresh: forceRefresh,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: object,
        forceRefresh: forceRefresh,
      ),
      ForemanWorkspaceRepository.fetchOverdueTasks(
        beforeDate: today,
        objectName: object,
      ),
    ]);

    final todayTasks = results[2] as List<TaskItemData>;
    final overdueTasks = results[3] as List<TaskItemData>;
    final meta = await ForemanWorkspaceRepository.fetchTaskMeta(
      <String?>[
        ...todayTasks.map((task) => task.id),
        ...overdueTasks.map((task) => task.id),
      ],
    );

    return ForemanDashboardData(
      employees: results[0] as List<Employee>,
      shifts: results[1] as Map<String, double>,
      todayTasks: todayTasks,
      overdueTasks: overdueTasks,
      meta: meta,
    );
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        NotificationBell(selectedObjectName: objectName),
        IconButton.filledTonal(
          tooltip: 'Обновить смену',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        OutlinedButton.icon(
          onPressed: widget.onOpenTimesheet,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Заполнить табель'),
        ),
        OutlinedButton.icon(
          onPressed: widget.onOpenTasks,
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Все задачи'),
        ),
        FilledButton.icon(
          onPressed: widget.onAddTask,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить задачу'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ForemanDashboardData>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[
          ForemanShiftIdentity(objectName: objectName),
          const SizedBox(height: 18),
        ];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.engineering_outlined,
              title: 'Загружаем рабочую смену',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить рабочую смену',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          children.add(
            ForemanHomeMetrics(
              data: data,
              onOpenTimesheet: widget.onOpenTimesheet,
              onOpenTasks: widget.onOpenTasks,
            ),
          );
          children.add(const SizedBox(height: 18));
          children.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: ForemanTodayTasks(
                    data: data,
                    onOpenTasks: widget.onOpenTasks,
                    onAddTask: widget.onAddTask,
                    onOpenTask: widget.onOpenTask,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: ForemanAttendanceControl(
                    data: data,
                    onOpenTimesheet: widget.onOpenTimesheet,
                  ),
                ),
              ],
            ),
          );
          children.add(const SizedBox(height: 20));
          children.add(
            ForemanOverdueTasks(
              data: data,
              onOpenTask: widget.onOpenTask,
            ),
          );
        }

        return SpecialistDesktopPage(
          storageKey:
              'desktop-foreman-home-${objectName.isEmpty ? 'none' : objectName}',
          title: 'Рабочая смена',
          subtitle:
              'Задачи, исполнители, табель и контроль результатов на одном экране',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}
