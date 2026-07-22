import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import 'adaptive_legal_matters_screen.dart';

class LegalManagerSummaryScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalManagerSummaryScreen({super.key, required this.profile});

  @override
  State<LegalManagerSummaryScreen> createState() =>
      _LegalManagerSummaryScreenState();
}

class _LegalManagerSummaryScreenState extends State<LegalManagerSummaryScreen> {
  late Future<LegalDashboardData> future;

  @override
  void initState() {
    super.initState();
    future = LegalRepository.fetchDashboard();
  }

  Future<void> refresh() async {
    final next = LegalRepository.fetchDashboard();
    setState(() => future = next);
    await next;
  }

  Widget summaryTile(
    String title,
    int count,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Юридическая сводка'),
      ),
      body: AppPage(
        title: 'Юридическая сводка',
        subtitle: 'Риски, решения, согласования и недельный отчёт юриста',
        child: FutureBuilder<LegalDashboardData>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final data = snapshot.data!;
            final report = data.latestReport;
            return Column(
              children: [
                summaryTile(
                  'Требуется моё решение',
                  data.managerDecisions.length,
                  Icons.approval_outlined,
                  () => Navigator.push<void>(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => AdaptiveLegalMattersScreen(
                        profile: widget.profile,
                        managerOnly: true,
                      ),
                    ),
                  ),
                ),
                summaryTile(
                  'Критические и высокие риски',
                  data.highRisks.length,
                  Icons.warning_amber_rounded,
                  () => Navigator.push<void>(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => AdaptiveLegalMattersScreen(
                        profile: widget.profile,
                        highRiskOnly: true,
                      ),
                    ),
                  ),
                ),
                summaryTile(
                  'Ожидают подписи',
                  data.awaitingSignature.length,
                  Icons.draw_outlined,
                  () => Navigator.push<void>(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => const LegalDocumentsScreen(
                        initialStatus: LegalDocumentStatus.awaitingSignature,
                      ),
                    ),
                  ),
                ),
                summaryTile(
                  'Истекают или просрочены',
                  data.expiring.length,
                  Icons.event_busy_outlined,
                  () => Navigator.push<void>(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) =>
                          const LegalDocumentsScreen(attentionOnly: true),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Последний недельный отчёт',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (report == null)
                        const Text('Юрист ещё не отправлял недельный отчёт')
                      else ...[
                        Text(
                          'Статус: ${report.status == 'submitted' ? 'Отправлен' : 'Черновик'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          report.authorComment.isEmpty
                              ? 'Комментарий не добавлен'
                              : report.authorComment,
                        ),
                        if (report.managerDecisions.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Нужны решения:',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(report.managerDecisions),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Обновить'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
