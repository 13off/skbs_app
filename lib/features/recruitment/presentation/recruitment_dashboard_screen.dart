import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;

class RecruitmentDashboardScreen extends StatefulWidget {
  final AppUserProfile profile;
  final VoidCallback onOpenApplications;

  const RecruitmentDashboardScreen({
    super.key,
    required this.profile,
    required this.onOpenApplications,
  });

  @override
  State<RecruitmentDashboardScreen> createState() =>
      _RecruitmentDashboardScreenState();
}

class _RecruitmentDashboardScreenState
    extends State<RecruitmentDashboardScreen> {
  late Future<RecruitmentDashboardData> future;
  StreamSubscription<AppDataChange>? changesSubscription;

  @override
  void initState() {
    super.initState();
    future = load();
    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    changesSubscription?.cancel();
    super.dispose();
  }

  Future<RecruitmentDashboardData> load() {
    return RecruitmentRepository.fetchDashboard(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  Widget metric({
    required IconData icon,
    required String label,
    required int value,
    Color color = AppAdaptivePalette.telegramBlue,
  }) {
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: _text,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget metrics(RecruitmentDashboardData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        final spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: data.stages
              .map(
                (stage) => SizedBox(
                  width: width,
                  child: metric(
                    icon: stage.isFinal
                        ? Icons.flag_outlined
                        : Icons.view_column_outlined,
                    label: stage.title,
                    value: data.count(stage.id),
                    color: _stageColor(stage.colorHex),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget candidateTile(
    RecruitmentApplication application,
    RecruitmentDashboardData data,
  ) {
    final stage = data.stageFor(application);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 24,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppAdaptivePalette.telegramBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: AppAdaptivePalette.telegramBlue,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    <String>[
                      if (application.vacancy.isNotEmpty) application.vacancy,
                      if (application.objectName.isNotEmpty)
                        application.objectName,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stage?.title ?? application.statusTitle,
                  style: TextStyle(
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(application.createdAt),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Сегодня',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<RecruitmentDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 28,
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 46),
                  const SizedBox(height: 12),
                  Text(
                    'Не удалось загрузить HR-сводку',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final data =
              snapshot.data ??
              const RecruitmentDashboardData(
                applications: <RecruitmentApplication>[],
                stages: <RecruitmentPipelineStage>[],
                counts: <String, int>{},
              );
          final latest = data.applications.take(5).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metrics(data),
              const SizedBox(height: 18),
              PremiumActionButton(
                label: 'Все заявки · ${data.total}',
                icon: Icons.view_kanban_rounded,
                onPressed: widget.onOpenApplications,
              ),
              const SizedBox(height: 24),
              Text(
                'Последние заявки',
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              if (latest.isEmpty)
                PremiumWorkCard(
                  radius: 28,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 44, color: _muted),
                      const SizedBox(height: 12),
                      Text(
                        'Заявок пока нет',
                        style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...latest.map(
                  (application) => candidateTile(application, data),
                ),
            ],
          );
        },
      ),
    );
  }
}

Color _stageColor(String value) {
  final clean = value.replaceFirst('#', '');
  final parsed = int.tryParse(clean, radix: 16) ?? 0x2F80ED;
  return Color(0xFF000000 | parsed);
}
