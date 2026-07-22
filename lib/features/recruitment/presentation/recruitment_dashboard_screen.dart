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
Color get _success => AppAdaptivePalette.success;
Color get _warning => AppAdaptivePalette.warning;
Color get _danger => AppAdaptivePalette.danger;

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
    return Expanded(
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 14),
            Text(
              '$value',
              style: TextStyle(
                color: _text,
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget candidateTile(RecruitmentApplication application) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppAdaptivePalette.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppAdaptivePalette.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F2F4),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.person_search_rounded, color: _text),
            ),
            SizedBox(width: 12),
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
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  application.statusTitle,
                  style: TextStyle(
                    color: _text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  formatDate(application.createdAt),
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
      subtitle: '',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<RecruitmentDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 100),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded, size: 42),
                  SizedBox(height: 10),
                  Text(
                    'Не удалось загрузить HR-сводку',
                    style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted),
                  ),
                  SizedBox(height: 14),
                  FilledButton(
                    onPressed: refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final data =
              snapshot.data ??
              const RecruitmentDashboardData(
                applications: <RecruitmentApplication>[],
                counts: <String, int>{},
              );
          final latest = data.applications.take(5).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  metric(
                    icon: Icons.mark_email_unread_outlined,
                    label: 'Новые',
                    value: data.count('new'),
                  ),
                  SizedBox(width: 10),
                  metric(
                    icon: Icons.description_outlined,
                    label: 'Ждём документы',
                    value: data.count('documents'),
                    color: const Color(0xFF4C6076),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  metric(
                    icon: Icons.report_problem_outlined,
                    label: 'Косяки',
                    value: data.count('problems'),
                    color: _danger,
                  ),
                  SizedBox(width: 10),
                  metric(
                    icon: Icons.flight_takeoff_outlined,
                    label: 'Готовы к вылету',
                    value: data.count('ready'),
                    color: _success,
                  ),
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  metric(
                    icon: Icons.airplane_ticket_outlined,
                    label: 'Нужны билеты',
                    value: data.count('tickets'),
                    color: _warning,
                  ),
                  SizedBox(width: 10),
                  metric(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Оформлены',
                    value: data.count('completed'),
                    color: _success,
                  ),
                ],
              ),
              SizedBox(height: 18),
              FilledButton.icon(
                onPressed: widget.onOpenApplications,
                icon: Icon(Icons.view_kanban_outlined),
                label: Text('Все заявки · ${data.total}'),
              ),
              SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Последние заявки',
                      style: TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenApplications,
                    child: const Text('Открыть все'),
                  ),
                ],
              ),
              SizedBox(height: 8),
              if (latest.isEmpty)
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 40, color: _muted),
                      SizedBox(height: 10),
                      Text(
                        'Заявок пока нет',
                        style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'На первом этапе кандидатов можно добавлять вручную. Затем подключим Telegram-бота.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...latest.map(candidateTile),
            ],
          );
        },
      ),
    );
  }
}
