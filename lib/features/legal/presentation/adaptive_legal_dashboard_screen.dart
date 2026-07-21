import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_dashboard_screen.dart';
import 'legal_weekly_report_screen.dart';

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
  late Future<LegalDashboardData> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = LegalRepository.fetchDashboard();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.legal)) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    final next = LegalRepository.fetchDashboard();
    setState(() => future = next);
    await next;
  }

  void openWeeklyReport() {
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(builder: (_) => const LegalWeeklyReportScreen()),
    );
  }

  Color documentAccent(LegalDocument document) {
    if (document.isExpired || document.isActionOverdue) return specialistDanger;
    if (document.needsAttention) return specialistWarning;
    return specialistSuccess;
  }

  Color matterAccent(LegalMatter matter) {
    if (matter.riskLevel == 'critical' || matter.isOverdue) {
      return specialistDanger;
    }
    if (matter.isHighRisk || matter.needsManager) return specialistWarning;
    return specialistSuccess;
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
        OutlinedButton.icon(
          onPressed: widget.onOpenDocuments,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Документы'),
        ),
        OutlinedButton.icon(
          onPressed: widget.onOpenMatters,
          icon: const Icon(Icons.gavel_outlined),
          label: const Text('Вопросы'),
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
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Документы внимания',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenDocuments,
                child: const Text('Все документы'),
              ),
            ],
          ),
          Text(
            'Подписание, сроки, исправления и согласования',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (attention.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Критичных документов сейчас нет')),
            ),
          ...attention.take(7).map(
            (document) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: documentAccent(document).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
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
    final attention = matters
        .where((item) => item.isHighRisk || item.needsManager || item.isOverdue)
        .toList()
      ..sort((a, b) {
        final first = a.riskLevel == 'critical' ? 0 : a.isHighRisk ? 1 : 2;
        final second = b.riskLevel == 'critical' ? 0 : b.isHighRisk ? 1 : 2;
        return first.compareTo(second);
      });

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Риски и решения',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(
                onPressed: widget.onOpenMatters,
                child: const Text('Все вопросы'),
              ),
            ],
          ),
          Text(
            'Высокие риски, просрочки и вопросы руководителю',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (attention.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Срочных юридических вопросов нет')),
            ),
          ...attention.take(7).map(
            (matter) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: matterAccent(matter).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalDashboardData>(
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
          final data = snapshot.data!;
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
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.event_busy_outlined,
                    label: 'Истекают',
                    value: '${data.expiring.length}',
                    accent: specialistWarning,
                    onTap: widget.onOpenDocuments,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SpecialistMetricCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Высокие риски',
                    value: '${data.highRisks.length}',
                    accent: specialistDanger,
                    onTap: widget.onOpenMatters,
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: documentPanel(data.documents)),
                const SizedBox(width: 18),
                Expanded(child: matterPanel(data.matters)),
              ],
            ),
          ]);
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-legal-dashboard',
          title: 'Юридический контроль',
          subtitle:
              'Документы, сроки, риски и решения в одном рабочем пространстве',
          trailing: actionBar(),
          onRefresh: refresh,
          children: content,
        );
      },
    );
  }
}
