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
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
import '../navigation/app_page_route.dart';
import '../widgets/app_page.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';
import 'home_screen.dart';

const Color _desktopText = Color(0xFF1F2328);
const Color _desktopMuted = Color(0xFF6B7075);
const Color _desktopLine = Color(0xFFE6E8EB);
const Color _desktopSoft = Color(0xFFF2F3F5);
const Color _desktopSuccess = Color(0xFF22C55E);

class AdaptiveHomeScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const AdaptiveHomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
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
        );
      },
    );
  }
}

class _DesktopHomeDashboard extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const _DesktopHomeDashboard({
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<_DesktopHomeDashboard> createState() =>
      _DesktopHomeDashboardState();
}

class _DesktopHomeDashboardState extends State<_DesktopHomeDashboard> {
  static const String _allObjectsValue = '__all__';

  Future<_DesktopDashboardData>? dashboardFuture;
  StreamSubscription<AppDataChange>? dataChangeSubscription;

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

  @override
  void initState() {
    super.initState();
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
    final financePeriod = FinancePeriod.current(today);

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

  void openClassicHome() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => HomeScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
          onObjectChanged: widget.onObjectChanged,
        ),
      ),
    );
  }

  Widget buildObjectSelector(List<String> objectNames) {
    if (!widget.profile.isAdmin) {
      return _DesktopSelectorShell(
        icon: Icons.lock_outline_rounded,
        title: objectTitle,
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Выбрать объект',
      initialValue: cleanObjectName(widget.selectedObjectName) ??
          _allObjectsValue,
      onSelected: (value) {
        widget.onObjectChanged(value == _allObjectsValue ? null : value);
      },
      itemBuilder: (context) {
        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: _allObjectsValue,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.apartment_outlined),
              title: Text('Все объекты'),
            ),
          ),
          ...objectNames.map(
            (objectName) => PopupMenuItem<String>(
              value: objectName,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.business_outlined),
                title: Text(objectName),
              ),
            ),
          ),
        ];
      },
      child: _DesktopSelectorShell(
        icon: Icons.apartment_outlined,
        title: objectTitle,
        trailing: Icons.expand_more_rounded,
      ),
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
    final doneTasks =
        data.tasks.where((task) => task.status == 'Выполнено').length;
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
                    subtitle:
                        'Рабочая сводка по объектам, людям, задачам и выплатам',
                    trailing: NotificationBell(
                      selectedObjectName: widget.selectedObjectName,
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
                        _DesktopDateChip(
                          text: 'Сегодня, ${dateText(AppState.today)}',
                        ),
                        if (widget.profile.isAdmin) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: openClassicHome,
                            icon: const Icon(Icons.settings_outlined),
                            label: const Text('Управление объектами'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DesktopMetricCard(
                          icon: Icons.groups_2_outlined,
                          title: 'Сотрудники на объекте',
                          value: isLoading ? '...' : '$workedEmployees',
                          detail: isLoading ? 'Загрузка' : 'из $totalEmployees',
                          footer: 'На смене сегодня',
                          progress: employeeProgress,
                          accent: _desktopSuccess,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _DesktopMetricCard(
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Задачи на сегодня',
                          value: isLoading ? '...' : '$totalTasks',
                          detail: isLoading ? 'Загрузка' : 'всего',
                          footer: isLoading
                              ? 'Загрузка'
                              : 'Выполнено: $doneTasks',
                          progress: taskProgress,
                          accent: _desktopText,
                        ),
                      ),
                      if (widget.profile.isAdmin) ...[
                        const SizedBox(width: 18),
                        Expanded(
                          child: _DesktopMetricCard(
                            icon: Icons.account_balance_wallet_outlined,
                            title: 'Остаток к выплате',
                            value: isLoading
                                ? '...'
                                : formatMoney(data.finance.balance),
                            detail: 'за текущий месяц',
                            footer: isLoading
                                ? 'Загрузка'
                                : 'Выплачено: ${formatMoney(data.finance.paid)}',
                            progress: data.finance.paidProgress,
                            accent: _desktopText,
                            compactValue: true,
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
                        child: _DesktopTasksCard(tasks: data.tasks),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 5,
                        child: _DesktopFinanceCard(
                          visible: widget.profile.isAdmin,
                          accrued: data.finance.accrued,
                          paid: data.finance.paid,
                          balance: data.finance.balance,
                          formatMoney: formatMoney,
                          onOpenClassicHome: openClassicHome,
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
                  return _DesktopErrorState(onRetry: refresh);
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

class _DesktopSelectorShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final IconData? trailing;

  const _DesktopSelectorShell({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _desktopSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _desktopLine),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: _desktopMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _desktopText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (trailing != null) Icon(trailing, color: _desktopMuted),
        ],
      ),
    );
  }
}

class _DesktopDateChip extends StatelessWidget {
  final String text;

  const _DesktopDateChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _desktopLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined, color: _desktopMuted),
          const SizedBox(width: 9),
          Text(
            text,
            style: const TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final String footer;
  final double progress;
  final Color accent;
  final bool compactValue;

  const _DesktopMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.footer,
    required this.progress,
    required this.accent,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _desktopSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: _desktopText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _desktopText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _desktopText,
              fontSize: compactValue ? 28 : 38,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress.clamp(0.0, 1.0).toDouble(),
              backgroundColor: _desktopSoft,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            footer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _desktopMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTasksCard extends StatelessWidget {
  final List<TaskItemData> tasks;

  const _DesktopTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(6).toList(growable: false);

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Задачи сегодня',
            style: TextStyle(
              color: _desktopText,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Последние работы по выбранному объекту',
            style: TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (visibleTasks.isEmpty)
            const _DesktopEmptyState(
              icon: Icons.assignment_outlined,
              text: 'На сегодня задач нет',
            )
          else
            ...visibleTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _desktopSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _desktopLine),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: task.status == 'Выполнено'
                              ? _desktopSuccess
                              : _desktopMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.work.trim().isEmpty
                                  ? 'Работа без названия'
                                  : task.work.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _desktopText,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${task.objectName} · ${task.axes.trim().isEmpty ? 'оси не указаны' : task.axes}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _desktopMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        task.status,
                        style: const TextStyle(
                          color: _desktopMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopFinanceCard extends StatelessWidget {
  final bool visible;
  final double accrued;
  final double paid;
  final double balance;
  final String Function(double value) formatMoney;
  final VoidCallback onOpenClassicHome;

  const _DesktopFinanceCard({
    required this.visible,
    required this.accrued,
    required this.paid,
    required this.balance,
    required this.formatMoney,
    required this.onOpenClassicHome,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(20),
        child: _DesktopEmptyState(
          icon: Icons.dashboard_customize_outlined,
          text: 'Рабочая сводка обновляется автоматически',
        ),
      );
    }

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Выплаты за месяц',
            style: TextStyle(
              color: _desktopText,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _DesktopFinanceRow(
            label: 'Начислено',
            value: formatMoney(accrued),
          ),
          const Divider(height: 24),
          _DesktopFinanceRow(label: 'Выплачено', value: formatMoney(paid)),
          const Divider(height: 24),
          _DesktopFinanceRow(
            label: 'Остаток',
            value: formatMoney(balance),
            emphasized: true,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onOpenClassicHome,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Выбрать другой период'),
          ),
        ],
      ),
    );
  }
}

class _DesktopFinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _DesktopFinanceRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _desktopText,
            fontSize: emphasized ? 18 : 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DesktopEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DesktopEmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _desktopMuted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _DesktopErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PremiumWorkCard(
        radius: 26,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Не удалось загрузить сводку',
              style: TextStyle(
                color: _desktopText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
