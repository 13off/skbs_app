import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/notification_bell.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import 'legal_matters_screen.dart';
import 'legal_weekly_report_screen.dart';

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
      CupertinoPageRoute<void>(
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
      CupertinoPageRoute<void>(
        builder: (_) => LegalMattersScreen(
          highRiskOnly: highRiskOnly,
          managerOnly: managerOnly,
        ),
      ),
    );
  }

  void openWeeklyReport() {
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(builder: (_) => const LegalWeeklyReportScreen()),
    );
  }

  Widget metricCard({
    required String title,
    required int value,
    required IconData icon,
    required VoidCallback onTap,
    String subtitle = '',
  }) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: PremiumWorkCard(
        radius: 24,
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF3D4146)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7075),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8F94)),
          ],
        ),
      ),
    );
  }

  Widget activityCard(LegalDashboardData data) {
    final documents = data.documents.take(3).toList();
    final matters = data.matters.take(3).toList();
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Последние изменения',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (documents.isEmpty && matters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  'Изменений пока нет',
                  style: TextStyle(color: Color(0xFF6B7075)),
                ),
              ),
            ),
          ...documents.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item.statusTitle} • ${item.expiryTitle}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => openDocuments(),
            ),
          ),
          ...matters.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.gavel_outlined),
              title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      subtitle: 'Документы, сроки, юридические вопросы и решения руководителя',
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
                    Text(
                      'Не удалось загрузить юридическую сводку: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: refresh, child: const Text('Повторить')),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: refresh,
            child: Column(
              children: [
                metricCard(
                  title: 'Ожидают подписи',
                  value: data.awaitingSignature.length,
                  icon: Icons.draw_outlined,
                  onTap: () => openDocuments(
                    status: LegalDocumentStatus.awaitingSignature,
                  ),
                ),
                const SizedBox(height: 10),
                metricCard(
                  title: 'Истекают или просрочены',
                  value: data.expiring.length,
                  icon: Icons.event_busy_outlined,
                  onTap: () => openDocuments(attentionOnly: true),
                ),
                const SizedBox(height: 10),
                metricCard(
                  title: 'Высокие риски',
                  value: data.highRisks.length,
                  icon: Icons.warning_amber_rounded,
                  onTap: () => openMatters(highRiskOnly: true),
                ),
                const SizedBox(height: 10),
                metricCard(
                  title: 'Требуется решение руководителя',
                  value: data.managerDecisions.length,
                  icon: Icons.approval_outlined,
                  onTap: () => openMatters(managerOnly: true),
                ),
                const SizedBox(height: 14),
                PremiumActionButton(
                  label: 'Недельный отчёт',
                  icon: Icons.summarize_outlined,
                  onPressed: openWeeklyReport,
                ),
                const SizedBox(height: 14),
                activityCard(data),
              ],
            ),
          );
        },
      ),
    );
  }
}
