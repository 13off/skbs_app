import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../../tasks/presentation/employee_contribution_screen.dart';
import '../data/manager_reports_repository.dart';
import '../data/manager_weekly_contribution_repository.dart';
import 'employee_routes_report_screen.dart';
import 'manager_daily_ai_review.dart';
import 'manager_report_header_widgets.dart';
import 'manager_report_sections.dart';
import 'manager_report_tile.dart';
import 'manager_weekly_contribution_section.dart';
import '../../../navigation/app_page_route.dart';

class ManagerReportsScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const ManagerReportsScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<ManagerReportsScreen> createState() => _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends State<ManagerReportsScreen> {
  late DateTime reportDate;
  late Future<ManagerReportsCenter> future;
  late Future<ManagerWeeklyContributionReport> weeklyContributionFuture;
  String? selectedObjectId;
  bool onlyProblems = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    reportDate = DateTime(now.year, now.month, now.day);
    ManagerReportsRepository.setPreferredObjectName(widget.selectedObjectName);
    future = loadInitial();
    weeklyContributionFuture = future.then((_) => fetchWeeklyContribution());
  }

  @override
  void didUpdateWidget(covariant ManagerReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId == widget.profile.activeCompanyId) {
      return;
    }
    selectedObjectId = null;
    ManagerReportsRepository.setPreferredObjectName(widget.selectedObjectName);
    ManagerWeeklyContributionRepository.clearCache();
    future = loadInitial();
    weeklyContributionFuture = future.then((_) => fetchWeeklyContribution());
  }

  Future<ManagerReportsCenter> loadInitial() async {
    final center = await ManagerReportsRepository.fetch(reportDate: reportDate);
    selectedObjectId = center.selectedObject?.id;
    return center;
  }

  Future<void> reload() async {
    final nextReports = fetchReports(forceRefresh: true);
    final nextWeekly = fetchWeeklyContribution(forceRefresh: true);
    setState(() {
      future = nextReports;
      weeklyContributionFuture = nextWeekly;
    });
    await Future.wait<dynamic>([nextReports, nextWeekly]);
  }

  Future<ManagerReportsCenter> fetchReports({bool forceRefresh = false}) {
    return ManagerReportsRepository.fetch(
      objectId: selectedObjectId,
      reportDate: reportDate,
      forceRefresh: forceRefresh,
    );
  }

  Future<ManagerWeeklyContributionReport> fetchWeeklyContribution({
    bool forceRefresh = false,
  }) {
    return ManagerWeeklyContributionRepository.fetch(
      companyId: widget.profile.activeCompanyId,
      objectId: selectedObjectId,
      forceRefresh: forceRefresh,
    );
  }

  void changeDate(int days) {
    setState(() {
      reportDate = reportDate.add(Duration(days: days));
      future = fetchReports();
    });
  }

  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: reportDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value == null || !mounted) return;
    setState(() {
      reportDate = DateTime(value.year, value.month, value.day);
      future = fetchReports();
    });
  }

  void changeObject(ManagerReportsCenter center, String? value) {
    final nextId = value?.trim().isEmpty == true ? null : value;
    String? nextName;
    if (nextId != null) {
      for (final object in center.objects) {
        if (object.id == nextId) {
          nextName = object.name;
          break;
        }
      }
    }
    widget.onObjectChanged(nextName);
    setState(() {
      selectedObjectId = nextId;
      future = fetchReports();
      weeklyContributionFuture = fetchWeeklyContribution(forceRefresh: true);
    });
  }

  void openScreen(Widget screen) {
    Navigator.of(
      context,
    ).push<void>(AppPageRoute<void>(builder: (_) => screen));
  }

  void openRoutes() {
    openScreen(
      EmployeeRoutesReportScreen(selectedObjectName: widget.selectedObjectName),
    );
  }

  void openDailyReview(ManagerReportsCenter center) {
    openScreen(
      ManagerDailyAiReviewScreen(
        profile: widget.profile,
        center: center,
        onOpen: openScreen,
      ),
    );
  }

  void openContribution(ManagerWeeklyContributionEmployee item) {
    openScreen(
      EmployeeContributionScreen(
        employee: Employee(
          item.employeeName,
          item.position,
          'не отмечен',
          id: item.employeeId,
          objectId: item.objectId,
          objectName: item.objectName,
        ),
      ),
    );
  }

  Widget sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget quickReports(ManagerReportsCenter center) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle(context, 'Быстрые отчёты'),
        ManagerReportTile(
          icon: Icons.route_rounded,
          title: 'Маршруты сотрудников',
          meta: 'Передвижения и рабочие маршруты',
          onTap: openRoutes,
        ),
        ManagerReportTile(
          icon: Icons.auto_awesome_outlined,
          title: 'ИИ-разбор рабочего дня',
          meta: center.criticalCount > 0
              ? 'Требует внимания: ${center.criticalCount}'
              : 'Критичных отклонений нет',
          trailingLabel: center.criticalCount > 0
              ? '${center.criticalCount}'
              : null,
          onTap: () => openDailyReview(center),
        ),
        ManagerWeeklyContributionSection(
          future: weeklyContributionFuture,
          onOpenEmployee: openContribution,
        ),
      ],
    );
  }

  Widget reportContent(ManagerReportsCenter center) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManagerReportFilters(
          center: center,
          selectedObjectId: selectedObjectId,
          reportDate: reportDate,
          onlyProblems: onlyProblems,
          onObjectChanged: (value) => changeObject(center, value),
          onPreviousDay: () => changeDate(-1),
          onNextDay: () => changeDate(1),
          onChooseDate: chooseDate,
          onOnlyProblemsChanged: (value) {
            setState(() => onlyProblems = value);
          },
        ),
        const SizedBox(height: 12),
        ManagerReportOverview(center: center),
        const SizedBox(height: 20),
        quickReports(center),
        const SizedBox(height: 10),
        ManagerReportSections(
          profile: widget.profile,
          center: center,
          onlyProblems: onlyProblems,
          onOpen: openScreen,
        ),
      ],
    );
  }

  Widget loading() {
    return const PremiumWorkCard(
      radius: 28,
      child: Padding(
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget loadError(Object? error) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить отчёты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Отчёты',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationBell(selectedObjectName: widget.selectedObjectName),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: FutureBuilder<ManagerReportsCenter>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return loading();
          }
          if (snapshot.hasError) return loadError(snapshot.error);
          return reportContent(snapshot.data!);
        },
      ),
    );
  }
}
