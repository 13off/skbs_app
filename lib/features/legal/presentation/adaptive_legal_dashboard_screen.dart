import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_dashboard_screen.dart';
import 'legal_weekly_report_screen.dart';
import '../../../navigation/app_page_route.dart';

class AdaptiveLegalDashboardScreen extends StatelessWidget {
  final AppUserProfile profile;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenMatters;
  final ValueChanged<LegalDocument> onOpenDocument;
  final ValueChanged<LegalMatter> onOpenMatter;

  const AdaptiveLegalDashboardScreen({
    super.key,
    required this.profile,
    required this.onOpenDocuments,
    required this.onOpenMatters,
    required this.onOpenDocument,
    required this.onOpenMatter,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return LegalDashboardScreen(profile: profile);
        }
        return _DesktopLegalDashboardScreen(
          onOpenDocuments: onOpenDocuments,
          onOpenMatters: onOpenMatters,
          onOpenDocument: onOpenDocument,
          onOpenMatter: onOpenMatter,
        );
      },
    );
  }
}

class _DesktopLegalDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenMatters;
  final ValueChanged<LegalDocument> onOpenDocument;
  final ValueChanged<LegalMatter> onOpenMatter;

  const _DesktopLegalDashboardScreen({
    required this.onOpenDocuments,
    required this.onOpenMatters,
    required this.onOpenDocument,
    required this.onOpenMatter,
  });

  @override
  State<_DesktopLegalDashboardScreen> createState() =>
      _DesktopLegalDashboardScreenState();
}

class _DesktopLegalDashboardScreenState
    extends State<_DesktopLegalDashboardScreen> {
  late Future<_LegalTodayData> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.legal)) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<_LegalTodayData> load() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchDashboard(),
      LegalWorkspaceRepository.fetchRecoveries(),
    ]);
    return _LegalTodayData(
      dashboard: values[0] as LegalDashboardData,
      recoveries: values[1] as List<LegalWorkspaceRecovery>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void openWeeklyReport() {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(builder: (_) => const LegalWeeklyReportScreen()),
    );
  }

  Color documentAccent(LegalDocument document) {
    if (document.isExpired || document.isActionOverdue) return specialistDanger;
    if (document.needsAttention) return specialistWarning;
    return specialistSuccess;
  }

  Color matterAccent(LegalMatter matter) {
    if (matter.riskLevel == 'critical' || matter.isOverdue)
      return specialistDanger;
    if (matter.isHighRisk || matter.needsManager) return specialistWarning;
    return specialistSuccess;
  }

  String date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  Widget actionBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        const NotificationBell(selectedObjectName: null),
        IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: openWeeklyReport,
          icon: const Icon(Icons.summarize_outlined),
          label: const Text('Недельный отчёт'),
        ),
      ],
    );
  }

  Widget documentPanel(List<LegalDocument> documents) {
    final attention = documents.where((item) => item.needsAttention).toList()
      ..sort((a, b) {
        final first = a.expiresOn ?? DateTime(9999);
        final second = b.expiresOn ?? DateTime(9999);
        return first.compareTo(second);
      });

    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Документы внимания',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (attention.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Критичных документов нет')),
            ),
          ...attention
              .take(7)
              .map(
                (document) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: documentAccent(document).withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: documentAccent(document),
                    ),
                  ),
                  title: Text(
                    document.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${document.statusTitle} • ${document.expiryTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onOpenDocument(document),
                ),
              ),
        ],
      ),
    );
  }

  Widget matterPanel(List<LegalMatter> matters) {
    final attention =
        matters
            .where(
              (item) => item.isHighRisk || item.needsManager || item.isOverdue,
            )
            .toList()
          ..sort((a, b) {
            final first = a.riskLevel == 'critical'
                ? 0
                : a.isHighRisk
                ? 1
                : 2;
            final second = b.riskLevel == 'critical'
                ? 0
                : b.isHighRisk
                ? 1
                : 2;
            return first.compareTo(second);
          });

    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Дела, риски и решения',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (attention.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: Text('Срочных дел нет')),
            ),
          ...attention
              .take(7)
              .map(
                (matter) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: matterAccent(matter).withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      matter.isHighRisk
                          ? Icons.warning_amber_rounded
                          : Icons.gavel_outlined,
                      color: matterAccent(matter),
                    ),
                  ),
                  title: Text(
                    matter.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${matter.riskTitle} риск • ${matter.statusTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => widget.onOpenMatter(matter),
                ),
              ),
        ],
      ),
    );
  }

  Widget recoveryPanel(List<LegalWorkspaceRecovery> recoveries) {
    final pending =
        recoveries.where((item) => item.status == 'pending').toList()
          ..sort((a, b) => b.absenceDate.compareTo(a.absenceDate));
    if (pending.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: PremiumWorkCard(
        radius: 28,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Взыскания ожидают решения • ${pending.length}',
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            const Text(
              'Юрист видит пакет документов; подтверждение или отмена выполняется руководителем в разделе «Штрафы».',
            ),
            const SizedBox(height: 10),
            ...pending
                .take(6)
                .map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.payments_outlined),
                    ),
                    title: Text(
                      '${item.employeeName} — ${item.amount.round()} ₽',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      <String>[
                        date(item.absenceDate),
                        if (item.objectName.isNotEmpty) item.objectName,
                        item.actFilePath.isNotEmpty
                            ? 'акт приложен'
                            : 'нет акта',
                        item.explanationFilePath.isNotEmpty
                            ? 'объяснительная приложена'
                            : 'нет объяснительной',
                      ].join(' • '),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LegalTodayData>(
      future: future,
      builder: (context, snapshot) {
        final content = <Widget>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          content.add(
            const SpecialistMessageCard(
              icon: Icons.gavel_outlined,
              title: 'Загружаем юридическую сводку',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          content.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить юридическую сводку',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final bundle = snapshot.data!;
          final data = bundle.dashboard;
          content.addAll([
            Row(
              children: [
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.draw_outlined,
                    label: 'Ожидают подписи',
                    value: '${data.awaitingSignature.length}',
                    onTap: widget.onOpenDocuments,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.event_busy_outlined,
                    label: 'Истекают',
                    value: '${data.expiring.length}',
                    accent: specialistWarning,
                    onTap: widget.onOpenDocuments,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Высокие риски',
                    value: '${data.highRisks.length}',
                    accent: specialistDanger,
                    onTap: widget.onOpenMatters,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.approval_outlined,
                    label: 'Решение руководителя',
                    value: '${data.managerDecisions.length}',
                    accent: specialistWarning,
                    onTap: widget.onOpenMatters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: documentPanel(data.documents)),
                const SizedBox(width: 20),
                Expanded(child: matterPanel(data.matters)),
              ],
            ),
            recoveryPanel(bundle.recoveries),
          ]);
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-legal-dashboard',
          title: 'Сегодня',
          subtitle: 'Только то, что требует действия или контроля',
          trailing: actionBar(),
          onRefresh: refresh,
          children: content,
        );
      },
    );
  }
}

class _LegalTodayData {
  final LegalDashboardData dashboard;
  final List<LegalWorkspaceRecovery> recoveries;

  const _LegalTodayData({required this.dashboard, required this.recoveries});
}
