import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../data/manager_reports_repository.dart';
import 'manager_report_widgets.dart';

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
  String? selectedObjectId;
  bool onlyProblems = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    reportDate = DateTime(now.year, now.month, now.day);
    ManagerReportsRepository.setPreferredObjectName(widget.selectedObjectName);
    future = loadInitial();
  }

  Future<ManagerReportsCenter> loadInitial() async {
    final center = await ManagerReportsRepository.fetch(reportDate: reportDate);
    selectedObjectId = center.selectedObject?.id;
    return center;
  }

  Future<void> reload() async {
    final next = fetchReports();
    setState(() => future = next);
    await next;
  }

  Future<ManagerReportsCenter> fetchReports() {
    return ManagerReportsRepository.fetch(
      objectId: selectedObjectId,
      reportDate: reportDate,
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
    });
  }

  void openScreen(Widget screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
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
        const SizedBox(height: 18),
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
      radius: 24,
      child: Padding(
        padding: EdgeInsets.all(36),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget loadError(Object? error) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Не удалось загрузить отчёты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text('$error'),
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
      subtitle: 'Единый центр аналитики руководителя',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NotificationBell(selectedObjectName: widget.selectedObjectName),
          const SizedBox(width: 6),
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
