import 'dart:async';
import 'dart:math' as math;

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
import 'employees_screen.dart';
import 'home_screen.dart';
import 'payments_screen.dart';
import 'tasks_screen.dart';
import 'timesheet_screen.dart';

const Color _desktopText = Color(0xFF1F2328);
const Color _desktopMuted = Color(0xFF6B7075);
const Color _desktopLine = Color(0xFFE6E8EB);
const Color _desktopSoft = Color(0xFFF2F3F5);
const Color _desktopSuccess = Color(0xFF22C55E);
const Color _desktopDanger = Color(0xFF9D3E38);

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

  void openEmployees() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => EmployeesScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  void openTimesheet() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => TimesheetScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  void openTasks() {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => TasksScreen(
          profile: widget.profile,
          selectedObjectName: widget.selectedObjectName,
        ),
      ),
    );
  }

  void openPayments() {
    if (!widget.profile.isAdmin) return;

    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => PaymentsScreen(
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
                              color: selected ? _desktopSoft : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? _desktopText
                                    : _desktopLine,
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
        return _ObjectManagementDialog(
          selectedObjectName: widget.selectedObjectName,
          onObjectChanged: widget.onObjectChanged,
          onDataChanged: refresh,
        );
      },
    );
  }

  Widget buildObjectSelector(List<String> objectNames) {
    if (!widget.profile.isAdmin) {
      return _DesktopSelectorShell(
        icon: Icons.lock_outline_rounded,
        title: objectTitle,
      );
    }

    return _DesktopObjectSelector(
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
                        'ПК-вид · рабочая сводка по объектам, людям, задачам и выплатам',
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
                        _DesktopDateChip(
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
                          onTap: widget.profile.isAdmin
                              ? openEmployees
                              : openTimesheet,
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
                          onTap: openTasks,
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
                            detail: financePeriod.title(),
                            footer: isLoading
                                ? 'Загрузка'
                                : 'Выплачено: ${formatMoney(data.finance.paid)}',
                            progress: data.finance.paidProgress,
                            accent: _desktopText,
                            compactValue: true,
                            onTap: openPayments,
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
                        child: _DesktopTasksCard(
                          tasks: data.tasks,
                          onOpenTasks: openTasks,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 5,
                        child: _DesktopFinanceCard(
                          visible: widget.profile.isAdmin,
                          periodTitle: financePeriod.pickerTitle(),
                          accrued: data.finance.accrued,
                          paid: data.finance.paid,
                          balance: data.finance.balance,
                          formatMoney: formatMoney,
                          onOpenPayments: openPayments,
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

class _DesktopObjectSelector extends StatefulWidget {
  final List<String> objectNames;
  final String? selectedObjectName;
  final ValueChanged<String?> onSelected;

  const _DesktopObjectSelector({
    required this.objectNames,
    required this.selectedObjectName,
    required this.onSelected,
  });

  @override
  State<_DesktopObjectSelector> createState() =>
      _DesktopObjectSelectorState();
}

class _DesktopObjectSelectorState extends State<_DesktopObjectSelector>
    with WidgetsBindingObserver {
  final LayerLink layerLink = LayerLink();
  final GlobalKey targetKey = GlobalKey();
  OverlayEntry? menuEntry;

  String? clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String get title => clean(widget.selectedObjectName) ?? 'Все объекты';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant _DesktopObjectSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName ||
        !listEquals(oldWidget.objectNames, widget.objectNames)) {
      closeMenu();
    }
  }

  @override
  void didChangeMetrics() {
    closeMenu();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    closeMenu();
    super.dispose();
  }

  void closeMenu() {
    menuEntry?.remove();
    menuEntry = null;
  }

  void selectObject(String? value) {
    closeMenu();
    widget.onSelected(value);
  }

  void toggleMenu() {
    if (menuEntry != null) {
      closeMenu();
      return;
    }

    final targetContext = targetKey.currentContext;
    final renderBox = targetContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final targetSize = renderBox.size;
    final menuWidth = math
        .min(math.max(targetSize.width, 420), 560)
        .toDouble();
    final overlay = Overlay.of(context);

    menuEntry = OverlayEntry(
      builder: (overlayContext) {
        final maxHeight = math.min(
          420.0,
          MediaQuery.sizeOf(overlayContext).height * 0.58,
        );
        final selected = clean(widget.selectedObjectName);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _desktopLine),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 34,
                        spreadRadius: -8,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Text(
                          'Выберите объект',
                          style: TextStyle(
                            color: _desktopMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            _DesktopObjectMenuItem(
                              icon: Icons.apartment_outlined,
                              title: 'Все объекты',
                              selected: selected == null,
                              onTap: () => selectObject(null),
                            ),
                            ...widget.objectNames.map(
                              (objectName) => _DesktopObjectMenuItem(
                                icon: Icons.business_outlined,
                                title: objectName,
                                selected: selected == objectName,
                                onTap: () => selectObject(objectName),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(menuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      key: targetKey,
      link: layerLink,
      child: Tooltip(
        message: 'Выбрать объект',
        child: PremiumPressable(
          onTap: toggleMenu,
          borderRadius: BorderRadius.circular(18),
          child: _DesktopSelectorShell(
            icon: Icons.apartment_outlined,
            title: title,
            trailing: Icons.expand_more_rounded,
          ),
        ),
      ),
    );
  }
}

class _DesktopObjectMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopObjectMenuItem({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          minHeight: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _desktopSoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _desktopText : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _desktopMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _desktopText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, size: 21),
            ],
          ),
        ),
      ),
    );
  }
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
  final VoidCallback onTap;

  const _DesktopDateChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Обновить данные за сегодня',
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
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
              const SizedBox(width: 9),
              const Icon(Icons.refresh_rounded, size: 18, color: _desktopMuted),
            ],
          ),
        ),
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
  final VoidCallback onTap;
  final bool compactValue;

  const _DesktopMetricCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.footer,
    required this.progress,
    required this.accent,
    required this.onTap,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: PremiumWorkCard(
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
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: _desktopMuted,
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
      ),
    );
  }
}

class _DesktopTasksCard extends StatelessWidget {
  final List<TaskItemData> tasks;
  final VoidCallback onOpenTasks;

  const _DesktopTasksCard({
    required this.tasks,
    required this.onOpenTasks,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(6).toList(growable: false);

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Задачи сегодня',
                      style: TextStyle(
                        color: _desktopText,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Последние работы по выбранному объекту',
                      style: TextStyle(
                        color: _desktopMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenTasks,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Все задачи'),
              ),
            ],
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
                child: PremiumPressable(
                  onTap: onOpenTasks,
                  borderRadius: BorderRadius.circular(18),
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
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: _desktopMuted,
                        ),
                      ],
                    ),
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
  final String periodTitle;
  final double accrued;
  final double paid;
  final double balance;
  final String Function(double value) formatMoney;
  final VoidCallback onOpenPayments;
  final VoidCallback onPickPeriod;

  const _DesktopFinanceCard({
    required this.visible,
    required this.periodTitle,
    required this.accrued,
    required this.paid,
    required this.balance,
    required this.formatMoney,
    required this.onOpenPayments,
    required this.onPickPeriod,
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выплаты',
                      style: TextStyle(
                        color: _desktopText,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      periodTitle,
                      style: const TextStyle(
                        color: _desktopMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenPayments,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Открыть'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PremiumPressable(
            onTap: onOpenPayments,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _desktopSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _desktopLine),
              ),
              child: Column(
                children: [
                  _DesktopFinanceRow(
                    label: 'Начислено',
                    value: formatMoney(accrued),
                  ),
                  const Divider(height: 24),
                  _DesktopFinanceRow(
                    label: 'Выплачено',
                    value: formatMoney(paid),
                  ),
                  const Divider(height: 24),
                  _DesktopFinanceRow(
                    label: 'Остаток',
                    value: formatMoney(balance),
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onPickPeriod,
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PremiumWorkCard(
          radius: 26,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: _desktopMuted,
              ),
              const SizedBox(height: 14),
              const Text(
                'Не удалось загрузить главную',
                style: TextStyle(
                  color: _desktopText,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверь интернет и повтори загрузку.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _desktopMuted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectManagementDialog extends StatefulWidget {
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;
  final Future<void> Function() onDataChanged;

  const _ObjectManagementDialog({
    required this.selectedObjectName,
    required this.onObjectChanged,
    required this.onDataChanged,
  });

  @override
  State<_ObjectManagementDialog> createState() =>
      _ObjectManagementDialogState();
}

class _ObjectManagementDialogState extends State<_ObjectManagementDialog> {
  List<String> activeObjects = const <String>[];
  List<String> archivedObjects = const <String>[];
  bool loading = true;
  bool busy = false;
  String? errorText;

  String? clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  void initState() {
    super.initState();
    loadObjects();
  }

  Future<void> loadObjects() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final results = await Future.wait<List<String>>([
        ObjectRepository.fetchObjectNames(forceRefresh: true),
        ObjectRepository.fetchArchivedObjectNames(forceRefresh: true),
      ]);

      if (!mounted) return;
      setState(() {
        activeObjects = results[0];
        archivedObjects = results[1];
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString();
      });
    }
  }

  Future<String?> requestName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Название объекта',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Введите название объекта';
                if (text.length < 2) return 'Название слишком короткое';
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> confirmArchive(String objectName) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Архивировать объект?'),
              content: Text(
                'Объект «$objectName» исчезнет из рабочего списка. Данные сохранятся.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Архивировать'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;

    setState(() {
      busy = true;
      errorText = null;
    });

    try {
      await action();
      await loadObjects();
      await widget.onDataChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Future<void> addObject() async {
    final name = await requestName(title: 'Новый объект');
    if (name == null) return;

    await runAction(() async {
      final savedName = await ObjectRepository.addObject(name: name);
      widget.onObjectChanged(savedName);
    });
  }

  Future<void> renameObject(String oldName) async {
    final newName = await requestName(
      title: 'Переименовать объект',
      initialValue: oldName,
    );
    if (newName == null || newName == oldName) return;

    await runAction(() async {
      final savedName = await ObjectRepository.renameObject(
        oldName: oldName,
        newName: newName,
      );
      if (clean(widget.selectedObjectName) == oldName) {
        widget.onObjectChanged(savedName);
      }
    });
  }

  Future<void> archiveObject(String objectName) async {
    if (!await confirmArchive(objectName)) return;

    await runAction(() async {
      await ObjectRepository.archiveObject(name: objectName);
      if (clean(widget.selectedObjectName) == objectName) {
        widget.onObjectChanged(null);
      }
    });
  }

  Future<void> restoreObject(String objectName) async {
    await runAction(() async {
      await ObjectRepository.restoreObject(name: objectName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = clean(widget.selectedObjectName);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Управление объектами',
                          style: TextStyle(
                            color: _desktopText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Создание, переименование, архив и восстановление',
                          style: TextStyle(
                            color: _desktopMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : addObject,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Добавить объект'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    tooltip: 'Закрыть',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _desktopDanger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      color: _desktopDanger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          _ObjectSectionTitle(
                            title: 'Активные объекты',
                            count: activeObjects.length,
                          ),
                          const SizedBox(height: 8),
                          if (activeObjects.isEmpty)
                            const _DesktopEmptyState(
                              icon: Icons.business_outlined,
                              text: 'Активных объектов пока нет',
                            )
                          else
                            ...activeObjects.map(
                              (objectName) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected == objectName
                                        ? _desktopSoft
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected == objectName
                                          ? _desktopText
                                          : _desktopLine,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        color: _desktopMuted,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          objectName,
                                          style: const TextStyle(
                                            color: _desktopText,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (selected == objectName)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Text(
                                            'Выбран',
                                            style: TextStyle(
                                              color: _desktopMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => widget.onObjectChanged(
                                                    objectName,
                                                  ),
                                          child: const Text('Выбрать'),
                                        ),
                                      IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => renameObject(objectName),
                                        tooltip: 'Переименовать',
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => archiveObject(objectName),
                                        tooltip: 'Архивировать',
                                        icon: const Icon(
                                          Icons.archive_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                          _ObjectSectionTitle(
                            title: 'Архив',
                            count: archivedObjects.length,
                          ),
                          const SizedBox(height: 8),
                          if (archivedObjects.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Архив пуст',
                                style: TextStyle(
                                  color: _desktopMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            ...archivedObjects.map(
                              (objectName) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _desktopSoft,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _desktopLine),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.inventory_2_outlined,
                                        color: _desktopMuted,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          objectName,
                                          style: const TextStyle(
                                            color: _desktopText,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => restoreObject(objectName),
                                        icon: const Icon(
                                          Icons.restore_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Восстановить'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _ObjectSectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _desktopText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _desktopSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _desktopMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
