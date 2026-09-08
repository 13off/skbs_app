import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/task_completion_report_repository.dart';
import '../models/task_completion_report.dart';
import 'estimator_volumes_screen.dart';

class EstimatorMainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EstimatorMainScreen({super.key, required this.profile});

  @override
  State<EstimatorMainScreen> createState() => _EstimatorMainScreenState();
}

class _EstimatorMainScreenState extends State<EstimatorMainScreen> {
  late final PersistentTabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = PersistentTabController(pageCount: 3);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Widget page(int index) {
    return switch (index) {
      0 => const _EstimatorWorkScreen(),
      1 => const EstimatorVolumesScreen(),
      2 => ProfileScreen(profile: widget.profile),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PersistentTabShell(
      controller: tabs,
      navigationStorageKey: 'estimator',
      returnToFirstTabOnBack: true,
      items: const <ProfessionalBottomNavigationItem>[
        ProfessionalBottomNavigationItem(
          label: 'Работы',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Объёмы',
          icon: Icons.stacked_bar_chart_outlined,
          selectedIcon: Icons.stacked_bar_chart_rounded,
        ),
        ProfessionalBottomNavigationItem(
          label: 'Профиль',
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
        ),
      ],
      tabBuilder: (_, index) => page(index),
    );
  }
}

class _EstimatorWorkScreen extends StatefulWidget {
  const _EstimatorWorkScreen();

  @override
  State<_EstimatorWorkScreen> createState() => _EstimatorWorkScreenState();
}

class _EstimatorWorkScreenState extends State<_EstimatorWorkScreen> {
  late Future<List<TaskCompletionReport>> future;
  String filter = 'pending';

  @override
  void initState() {
    super.initState();
    future = TaskCompletionReportRepository.fetchQueue();
  }

  Future<void> refresh() async {
    final next = TaskCompletionReportRepository.fetchQueue();
    setState(() => future = next);
    await next;
  }

  int count(List<TaskCompletionReport> reports, String status) {
    return reports.where((report) => report.reviewStatus == status).length;
  }

  List<TaskCompletionReport> filtered(List<TaskCompletionReport> reports) {
    if (filter == 'all') return reports;
    return reports.where((report) => report.reviewStatus == filter).toList();
  }

  Color statusColor(TaskCompletionReport report) {
    if (report.isApproved) return const Color(0xFF3E7B62);
    if (report.isReturned) return const Color(0xFF985A51);
    return const Color(0xFF92713D);
  }

  String dateTitle(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Future<void> openReview(TaskCompletionReport report) async {
    if (!report.isPending) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReviewDialog(report: report),
    );
    if (changed == true && mounted) await refresh();
  }

  Widget metric(String title, int value, IconData icon) {
    return SizedBox(
      width: 200,
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppAdaptivePalette.textPrimary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
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

  Widget filterBar() {
    const items = <(String, String)>[
      ('pending', 'На проверке'),
      ('approved', 'Подтверждено'),
      ('returned', 'Возвращено'),
      ('all', 'Все'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => ChoiceChip(
              label: Text(item.$2),
              selected: filter == item.$1,
              onSelected: (_) => setState(() => filter = item.$1),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget reportCard(TaskCompletionReport report) {
    final details = <String>[
      report.objectName.trim(),
      report.axes.trim(),
      if (report.workLocation.trim() != report.axes.trim())
        report.workLocation.trim(),
    ].where((value) => value.isNotEmpty).toSet().join(' · ');
    final color = statusColor(report);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumPressable(
        onTap: report.isPending ? () => openReview(report) : null,
        borderRadius: BorderRadius.circular(24),
        child: PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.work.trim().isEmpty
                              ? 'Выполненная работа'
                              : report.work,
                          style: TextStyle(
                            color: AppAdaptivePalette.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            details,
                            style: TextStyle(
                              color: AppAdaptivePalette.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Text(
                      report.statusTitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 28,
                runSpacing: 12,
                children: [
                  _Fact(
                    label: report.isApproved ? 'Принято' : 'Заявлено',
                    value: report.isApproved
                        ? report.approvedVolumeTitle
                        : report.reportedVolumeTitle,
                  ),
                  _Fact(
                    label: 'Мастер',
                    value: report.submittedByName.trim().isEmpty
                        ? 'Не указано'
                        : report.submittedByName,
                  ),
                  _Fact(label: 'Передано', value: dateTitle(report.submittedAt)),
                ],
              ),
              if (report.completionComment.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  report.completionComment,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (report.reviewComment.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${report.isReturned ? 'Причина возврата' : 'Комментарий сметчика'}: ${report.reviewComment}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (report.isPending) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => openReview(report),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Проверить'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инженер-сметчик',
      subtitle: 'Фактически выполненные работы от мастеров',
      onRefresh: refresh,
      child: FutureBuilder<List<TaskCompletionReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 180,
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Не удалось загрузить · Повторить'),
                ),
              ),
            );
          }

          final all = snapshot.data ?? const <TaskCompletionReport>[];
          final items = filtered(all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  metric(
                    'На проверке',
                    count(all, 'pending'),
                    Icons.pending_actions_rounded,
                  ),
                  metric(
                    'Подтверждено',
                    count(all, 'approved'),
                    Icons.verified_outlined,
                  ),
                  metric(
                    'Возвращено',
                    count(all, 'returned'),
                    Icons.reply_all_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              filterBar(),
              const SizedBox(height: 14),
              if (items.isEmpty)
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      filter == 'pending'
                          ? 'Сейчас ничего не ждёт проверки'
                          : 'В этом разделе пока пусто',
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else
                ...items.map(reportCard),
            ],
          );
        },
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 230),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewDialog extends StatefulWidget {
  final TaskCompletionReport report;

  const _ReviewDialog({required this.report});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  late final TextEditingController quantityController;
  final commentController = TextEditingController();
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final quantity = widget.report.reportedQuantity;
    quantityController = TextEditingController(
      text: quantity == null ? '' : TaskCompletionReport.formatQuantity(quantity),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    commentController.dispose();
    super.dispose();
  }

  double? quantity() {
    final text = quantityController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorText = '$error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> approve() async {
    final raw = quantityController.text.trim();
    final value = quantity();
    if (raw.isNotEmpty && (value == null || value <= 0)) {
      setState(() => errorText = 'Укажите корректный подтверждённый объём');
      return;
    }
    await run(
      () => TaskCompletionReportRepository.approve(
        reportId: widget.report.id,
        approvedQuantity: value,
        comment: commentController.text,
      ),
    );
  }

  Future<void> returnToForeman() async {
    final comment = commentController.text.trim();
    if (comment.isEmpty) {
      setState(() => errorText = 'Укажите, что мастер должен исправить');
      return;
    }
    await run(
      () => TaskCompletionReportRepository.returnToForeman(
        reportId: widget.report.id,
        comment: comment,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return AlertDialog(
      title: const Text('Проверка выполненной работы'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report.work.trim().isEmpty ? 'Выполненная работа' : report.work,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                [report.objectName, report.axes, report.workLocation]
                    .where((value) => value.trim().isNotEmpty)
                    .toSet()
                    .join(' · '),
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 10,
                  children: [
                    _Fact(label: 'Мастер заявил', value: report.reportedVolumeTitle),
                    _Fact(
                      label: 'Мастер',
                      value: report.submittedByName.trim().isEmpty
                          ? 'Не указано'
                          : report.submittedByName,
                    ),
                  ],
                ),
              ),
              if (report.completionComment.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(report.completionComment),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Подтверждённый объём',
                  suffixText: report.unit.trim().isEmpty ? null : report.unit,
                  prefixIcon: const Icon(Icons.straighten_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                enabled: !saving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Комментарий инженера-сметчика',
                  hintText: 'Для возврата причина обязательна',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Закрыть'),
        ),
        OutlinedButton.icon(
          onPressed: saving ? null : returnToForeman,
          icon: const Icon(Icons.reply_rounded),
          label: const Text('Вернуть мастеру'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : approve,
          icon: saving
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Подтвердить'),
        ),
      ],
    );
  }
}
