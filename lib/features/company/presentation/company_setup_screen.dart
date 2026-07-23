import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/adaptive_employees_screen.dart';
import '../../../screens/adaptive_timesheet_screen.dart';
import '../../../screens/notification_control_center_screen.dart';
import '../../../screens/tasks_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../compliance/presentation/company_compliance_screen.dart';
import '../../developer/presentation/developer_demo_center_screen.dart';
import '../data/company_setup_repository.dart';
import 'company_management_screen.dart';

class CompanySetupScreen extends StatefulWidget {
  final AppUserProfile profile;

  const CompanySetupScreen({super.key, required this.profile});

  @override
  State<CompanySetupScreen> createState() => _CompanySetupScreenState();
}

class _CompanySetupScreenState extends State<CompanySetupScreen> {
  late Future<CompanySetupProgress> progressFuture;

  @override
  void initState() {
    super.initState();
    progressFuture = CompanySetupRepository.fetch(widget.profile);
  }

  void refresh() {
    setState(() {
      progressFuture = CompanySetupRepository.fetch(widget.profile);
    });
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(CupertinoPageRoute<void>(builder: (_) => screen));
    if (mounted) refresh();
  }

  Future<void> openStep(CompanySetupStep step) async {
    final profile = widget.profile;
    switch (step.action) {
      case CompanySetupAction.company:
      case CompanySetupAction.objects:
      case CompanySetupAction.team:
        await open(CompanyManagementScreen(companyId: profile.activeCompanyId));
      case CompanySetupAction.employees:
        await open(
          AdaptiveEmployeesScreen(profile: profile, selectedObjectName: null),
        );
      case CompanySetupAction.tasks:
        await open(TasksScreen(profile: profile, selectedObjectName: null));
      case CompanySetupAction.attendance:
        await open(
          AdaptiveTimesheetScreen(profile: profile, selectedObjectName: null),
        );
      case CompanySetupAction.notifications:
        await open(const NotificationControlCenterScreen());
      case CompanySetupAction.compliance:
        await open(CompanyComplianceScreen(profile: profile));
    }
  }

  Widget progressCard(CompanySetupProgress progress) {
    final percent = (progress.progress * 100).round();
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: progress.coreCompleted
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  progress.coreCompleted
                      ? Icons.verified_rounded
                      : Icons.rocket_launch_outlined,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.companyName,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.coreCompleted
                          ? 'Компания готова к базовой работе'
                          : 'Следующий шаг: ${progress.nextRequiredStep?.title ?? 'проверить настройки'}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress.progress,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${progress.completedRequired} из ${progress.requiredSteps.length} обязательных шагов',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget stepCard(CompanySetupStep step) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => openStep(step),
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: step.completed
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  step.completed
                      ? Icons.check_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!step.required)
                          Text(
                            'РЕКОМЕНДУЕТСЯ',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Запуск компании',
      showBackButton: true,
      subtitle: 'Пошаговая настройка первого рабочего контура',
      headerTrailing: IconButton(
        tooltip: 'Проверить снова',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<CompanySetupProgress>(
        future: progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return PremiumWorkCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Не удалось проверить запуск компании: ${snapshot.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            );
          }

          final progress = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              progressCard(progress),
              const SizedBox(height: 16),
              ...progress.steps.map(stepCard),
              const SizedBox(height: 6),
              PremiumPressable(
                onTap: () => open(const DeveloperDemoCenterScreen()),
                borderRadius: BorderRadius.circular(22),
                child: const PremiumWorkCard(
                  radius: 22,
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.science_outlined),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Открыть безопасное демо на полностью вымышленных данных',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Проверка только читает состояние компании. Она не создаёт сотрудников, задачи, табель или выплаты автоматически.',
                style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
              ),
            ],
          );
        },
      ),
    );
  }
}
