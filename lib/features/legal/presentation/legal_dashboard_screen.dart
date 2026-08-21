import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skbs_app/app/app_adaptive_palette.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'adaptive_legal_matters_screen.dart';
import 'legal_documents_screen.dart';
import 'legal_weekly_report_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalDashboardScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalDashboardScreen({super.key, required this.profile});

  @override
  State<LegalDashboardScreen> createState() => _LegalDashboardScreenState();
}

class _LegalDashboardScreenState extends State<LegalDashboardScreen> {
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

  void openDocuments({bool attentionOnly = false, String? status}) {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => LegalDocumentsScreen(
          attentionOnly: attentionOnly,
          initialStatus: status,
        ),
      ),
    );
  }

  void openMatters({bool highRiskOnly = false, bool managerOnly = false}) {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => AdaptiveLegalMattersScreen(
          highRiskOnly: highRiskOnly,
          managerOnly: managerOnly,
          profile: widget.profile,
        ),
      ),
    );
  }

  void openWeeklyReport() {
    Navigator.push<void>(
      context,
      AppPageRoute<void>(builder: (_) => const LegalWeeklyReportScreen()),
    );
  }

  Widget metricCard({
    required String title,
    required int value,
    required IconData icon,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final effective = accent ?? scheme.primary;
    return PremiumPressable(
      onTap: onTap,
      pressedScale: 0.975,
      hoverScale: 1.012,
      borderRadius: BorderRadius.circular(28),
      child: PremiumWorkCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    effective.withValues(alpha: 0.22),
                    effective.withValues(alpha: 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: effective.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: effective, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: AppAdaptivePalette.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  Widget activityCard(LegalDashboardData data) {
    final documents = data.documents.take(3).toList();
    final matters = data.matters.take(3).toList();
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние изменения',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty && matters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Изменений пока нет',
                  style: TextStyle(color: AppAdaptivePalette.textMuted),
                ),
              ),
            ),
          ...documents.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${item.statusTitle} • ${item.expiryTitle}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openDocuments(),
            ),
          ),
          ...matters.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${item.riskTitle} риск • ${item.statusTitle}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openMatters(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Сегодня',
      headerTrailing: const NotificationBell(selectedObjectName: null),
      child: FutureBuilder<LegalDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumWorkCard(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 42),
                    const SizedBox(height: 12),
                    const Text(
                      'Не удалось загрузить юридическую сводку',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return Column(
            children: [
              metricCard(
                title: 'Ожидают подписи',
                value: data.awaitingSignature.length,
                icon: Icons.draw_outlined,
                onTap: () => openDocuments(
                  status: LegalDocumentStatus.awaitingSignature,
                ),
              ),
              const SizedBox(height: 12),
              metricCard(
                title: 'Истекают или просрочены',
                value: data.expiring.length,
                icon: Icons.event_busy_outlined,
                accent: AppAdaptivePalette.warning,
                onTap: () => openDocuments(attentionOnly: true),
              ),
              const SizedBox(height: 12),
              metricCard(
                title: 'Высокие риски',
                value: data.highRisks.length,
                icon: Icons.warning_amber_rounded,
                accent: AppAdaptivePalette.danger,
                onTap: () => openMatters(highRiskOnly: true),
              ),
              const SizedBox(height: 12),
              metricCard(
                title: 'Решение руководителя',
                value: data.managerDecisions.length,
                icon: Icons.approval_outlined,
                accent: AppAdaptivePalette.warning,
                onTap: () => openMatters(managerOnly: true),
              ),
              const SizedBox(height: 16),
              PremiumActionButton(
                label: 'Недельный отчёт',
                icon: Icons.summarize_outlined,
                onPressed: openWeeklyReport,
              ),
              const SizedBox(height: 16),
              activityCard(data),
            ],
          );
        },
      ),
    );
  }
}
