import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/finance_summary_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/ai/presentation/ai_assistant_screen.dart';
import '../features/milestones/presentation/milestone_home_overlay.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
import '../navigation/app_page_route.dart';
import '../widgets/app_page.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';
import 'desktop_home_widgets.dart';
import 'desktop_object_management_dialog.dart';
import 'home_screen.dart';

const Color _desktopText = Color(0xFF1F2328);
const Color _desktopMuted = Color(0xFF6B7075);
const Color _desktopSuccess = Color(0xFF22C55E);

class AdaptiveHomeScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;
  final Future<void> Function() onOpenEmployees;
  final Future<void> Function() onOpenTimesheet;
  final Future<void> Function() onOpenTasks;
  final Future<void> Function(TaskItemData task) onOpenTask;
  final Future<void> Function() onOpenPayments;

  const AdaptiveHomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
    required this.onOpenEmployees,
    required this.onOpenTimesheet,
    required this.onOpenTasks,
    required this.onOpenTask,
    required this.onOpenPayments,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopDashboard =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;

        if (!useDesktopDashboard) {
          return HomeScreen(
            profile: profile,
            selectedObjectName: selectedObjectName,
            onObjectChanged: onObjectChanged,
          );
        }

        return _DesktopHomeDashboard(
          profile: profile,
          selectedObjectName: selectedObjectName,
          onObjectChanged: onObjectChanged,
          onOpenEmployees: onOpenEmployees,
          onOpenTimesheet: onOpenTimesheet,
          onOpenTasks: onOpenTasks,
          onOpenTask: onOpenTask,
          onOpenPayments: onOpenPayments,
        );
      },
    );
  }
}

class _DesktopHomeDashboard extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;
  final Future<void> Function() onOpenEmployees;
  final Future<void> Function() onOpenTimesheet;
  final Future<void> Function() onOpenTasks;
  final Future<void> Function(TaskItemData task) onOpenTask;
  final Future<void> Function() onOpenPayments;

  const _DesktopHomeDashboard({
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
    required this.onOpenEmployees,
    required this.onOpenTimesheet,
    required this.onOpenTasks,
    required this.onOpenTask,
    required this.onOpenPayments,
  });

  @override
  State<_DesktopHomeDashboard> createState() => _DesktopHomeDashboardState();
}

class _DesktopHomeDashboardState extends State<_DesktopHomeDashboard> {
  Future<_DesktopDashboardData>? dashboardFuture;
  StreamSubscription<AppDataChange>? dataChangeSubscription;
  late FinancePeriod financePeriod;

  @override
  void initState() {
    super.initState();
    financePeriod = FinancePeriod.current(AppState.today);
    dashboardFuture = loadDashboardData();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didUpdateWidget(covariant _DesktopHomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      dashboardFuture = loadDashboardData();
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    super.dispose();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  String get objectTitle {
    return cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';
  }

  bool isSamePeriod(FinancePeriod first, FinancePeriod second) {
    return first.year == second.year && first.month == second.month;
  }

  void handleDataChange(AppDataChange change) {
    const domains = <AppDataDomain>{
      AppDataDomain.attendance,
      AppDataDomain.payments,
      AppDataDomain.employees,
      AppDataDomain.tasks,
      AppDataDomain.objects,
    };

    if (!mounted || !change.affectsAny(domains)) return;

    setState(() {
      dashboardFuture = loadDashboardData(forceRefresh: true);
    });
  }

  Future<_DesktopDashboardData> loadDashboardData({
    bool forceRefresh = false,
  }) async {
    final today = AppState.today;
    final selectedObject = cleanObjectName(widget.selectedObjectName);

    final results = await Future.wait<dynamic>([
      EmployeeRepository.fetchEmployees(
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      AttendanceRepository.fetchWorkedEmployeeIds(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      TaskRepository.fetchTasksForDate(
        today,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      FinanceSummaryRepository.fetchSummary(
        period: financePeriod,
        objectName: selectedObject,
        forceRefresh: forceRefresh,
      ),
      ObjectRepository.fetchObjectNames(forceRefresh: forceRefresh),
    ]);

    final objectNames = results[4] as List<String>;
    var tasks = results[2] as List<TaskItemData>;

    if (selectedObject == null) {
      final activeObjects = objectNames.toSet();
      tasks = tasks
          .where((task) => activeObjects.contains(task.objectName.trim()))
          .toList(growable: false);
    }

    return _DesktopDashboardData(
      employees: results[0] as List<Employee>,
      workedEmployeeIds: results[1] as Set<String>,
      tasks: tasks,
      finance: results[3] as FinanceSummaryData,
      objectNames: objectNames,
    );
  }

  Future<void> refresh() async {
    setState(() {
      dashboardFuture = loadDashboardData(forceRefresh: true);
    });
    await dashboardFuture;
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

  String formatMoney(double value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[index]);
    }

    return '${negative ? '-' : ''}${buffer.toString()} ₽';
  }

  void openAiAssistant() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => AiAssistantScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  Future<void> showFinancePeriodPicker() async {
    if (!widget.profile.isAdmin) return;

    final periods = <FinancePeriod>[
      const FinancePeriod.allTime(),
      ...FinancePeriod.recentMonths(AppState.today, count: 18),
    ];

    final picked = await showDialog<FinancePeriod>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Период выплат',
                          style: TextStyle(
                            color: _desktopText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        tooltip: 'Закрыть',
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: periods.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final period = periods[index];
                        final selected = isSamePeriod(period, financePeriod);

                        return PremiumPressable(
                          onTap: () => Navigator.pop(dialogContext, period),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFF2F3F5)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? _desktopText
                                    : const Color(0xFFE6E8EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  period.isAllTime
                                      ? Icons.all_inclusive_rounded
                                      : Icons.calendar_month_outlined,
                                  color: _desktopMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    period.pickerTitle(),
                                    style: const TextStyle(
                                      color: _desktopText,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle_rounded),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (picked == null || isSamePeriod(picked, financePeriod)) return;

    setState(() {
      financePeriod = picked;
      dashboardFuture = loadDashboardData();
    });
  }

  Future<void> showObjectManager() async {
    if (!widget.profile.isAdmin) return;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return DesktopObjectManagementDialog(
          selectedObjectName: widget.selectedObjectName,
          onObjectChanged: widget.onObjectChanged,
          onDataChanged: refresh,
        );
      },
    );
  }

  Widget buildObjectSelector(List<String> objectNames) {
    if (!widget.profile.isAdmin) {
      return DesktopSelectorShell(
        icon: Icons.lock_outline_rounded,
        title: objectTitle,
      );
    }

    return DesktopObjectSelector(
      objectNames: objectNames,
      selectedObjectName: widget.selectedObjectName,
      onSelected: widget.onObjectChanged,
    );
  }

  Widget buildDashboard(_DesktopDashboardData data, {required bool isLoading}) {
    final employeeById = <String, Employee>{};
    final activeEmployeeNames = <String>{};

    for (final employee in data.employees) {
      final id = employee.id?.trim();
      if (id != null && id.isNotEmpty) employeeById[id] = employee;
      activeEmployeeNames.add(normalizeName(employee.name));
    }

    final workedEmployeeNames = <String>{};
    for (final employeeId in data.workedEmployeeIds) {
      final employee = employeeById[employeeId];
      if (employee != null) {
        workedEmployeeNames.add(normalizeName(employee.name));
      }
    }

    final totalEmployees = activeEmployeeNames.length;
    final workedEmployees = workedEmployeeNames.length;
    final totalTasks = data.tasks.length;
    final doneTasks = data.tasks
        .where((task) => task.status == 'Выполнено')
        .length;
    final employeeProgress = totalEmployees == 0
        ? 0.0
        : workedEmployees / totalEmployees;
    final taskProgress = totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppPageHeader(
                    title: 'Главная',
                    subtitle: '',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: refresh,
                          tooltip: 'Обновить данные',
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        NotificationBell(
                          selectedObjectName: widget.selectedObjectName,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  PremiumWorkCard(
                    radius: 26,
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(child: buildObjectSelector(data.objectNames)),
                        const SizedBox(width: 16),
                        DesktopDateChip(
                          text: 'Сегодня, ${dateText(AppState.today)}',
                          onTap: refresh,
                        ),
                        if (widget.profile.isAdmin) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: showObjectManager,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Управление объектами'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  MilestoneHomeSection(
                    profile: widget.profile,
                    selectedObjectName: widget.selectedObjectName,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DesktopMetricCard(
                          icon: Icons.groups_2_outlined,
                          title: 'Сотрудники на объекте',
                          value: isLoading ? '...' : '$workedEmployees',
                          detail: isLoading ? 'Загрузка' : 'из $totalEmployees',
                          footer: 'На смене сегодня',
                          progress: employeeProgress,
                          accent: _desktopSuccess,
                          onTap: () {
                            if (widget.profile.isAdmin) {
                              widget.onOpenEmployees();
                            } else {
                              widget.onOpenTimesheet();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: DesktopMetricCard(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Выполненные задачи',
                          value: isLoading ? '...' : '$doneTasks',
                          detail: isLoading ? 'Загрузка' : 'из $totalTasks',
                          footer: isLoading ? 'Загрузка' : 'За сегодня',
                          progress: taskProgress,
                          accent: _desktopText,
                          onTap: () => widget.onOpenTasks(),
                        ),
                      ),
                      if (widget.profile.isAdmin) ...[
                        const SizedBox(width: 18),
                        Expanded(
                          child: DesktopMetricCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Остаток к выплате',
                            value: isLoading
                                ? '...'
                                : formatMoney(data.finance.balance),
                            detail: financePeriod.title(),
                            footer: isLoading
                                ? 'Загрузка'
                                : 'Выплачено: ${formatMoney(data.finance.paid)}',
                            progress: data.finance.paidProgress,
                            accent: _desktopText,
                            compactValue: true,
                            onTap: () => widget.onOpenPayments(),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: DesktopTasksCard(
                          tasks: data.tasks,
                          onOpenTasks: () => widget.onOpenTasks(),
                          onOpenTask: (task) => widget.onOpenTask(task),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 5,
                        child: DesktopFinanceCard(
                          visible: widget.profile.isAdmin,
                          periodTitle: financePeriod.pickerTitle(),
                          accrued: data.finance.accrued,
                          paid: data.finance.paid,
                          balance: data.finance.balance,
                          formatMoney: formatMoney,
                          onOpenPayments: () => widget.onOpenPayments(),
                          onPickPeriod: showFinancePeriodPicker,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PremiumWorkBackdrop(
          child: SafeArea(
            child: FutureBuilder<_DesktopDashboardData>(
              future: dashboardFuture,
              builder: (context, snapshot) {
                final data = snapshot.data ?? _DesktopDashboardData.empty;
                final isLoading =
                    snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

                if (snapshot.hasError && !snapshot.hasData) {
                  return DesktopErrorState(onRetry: refresh);
                }

                return buildDashboard(data, isLoading: isLoading);
              },
            ),
          ),
        ),
        Positioned(
          right: 28,
          bottom: 20,
          child: SafeArea(
            top: false,
            left: false,
            child: FloatingActionButton.extended(
              heroTag: 'desktop-home-ai-assistant',
              onPressed: openAiAssistant,
              backgroundColor: _desktopText,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('ИИ-помощник'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopDashboardData {
  final List<Employee> employees;
  final Set<String> workedEmployeeIds;
  final List<TaskItemData> tasks;
  final FinanceSummaryData finance;
  final List<String> objectNames;

  const _DesktopDashboardData({
    required this.employees,
    required this.workedEmployeeIds,
    required this.tasks,
    required this.finance,
    required this.objectNames,
  });

  static const empty = _DesktopDashboardData(
    employees: <Employee>[],
    workedEmployeeIds: <String>{},
    tasks: <TaskItemData>[],
    finance: FinanceSummaryData.empty,
    objectNames: <String>[],
  );
}
