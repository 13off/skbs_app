import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../screens/profile_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../shell/presentation/persistent_tab_shell.dart';
import '../data/task_completion_report_repository.dart';
import '../models/task_completion_report.dart';

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
    tabs = PersistentTabController(pageCount: 2);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Widget page(int index) {
    return switch (index) {
      0 => _EstimatorWorkScreen(profile: widget.profile),
      1 => ProfileScreen(profile: widget.profile),
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
  final AppUserProfile profile;

  const _EstimatorWorkScreen({required this.profile});

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

  List<TaskCompletionReport> visible(List<TaskCompletionReport> items) {
    if (filter == 'all') return items;
    return items.where((item) => item.reviewStatus == filter).toList();
  }

  int count(List<TaskCompletionReport> items, String status) =>
      items.where((item) => item.reviewStatus == status).length;

  String dateTimeTitle(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Color statusColor(TaskCompletionReport item) {
    if (item.isApproved) return const Color(0xFF3E7B62);
    if (item.isReturned) return const Color(0xFF9A5A51);
    return const Color(0xFF9A7438);
  }

  Future<void> review(TaskCompletionReport report) async {
    if (!report.isPending) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EstimatorReviewDialog(report: report),
    );
    if (changed == true && mounted) await refresh();
  }

  Widget metric({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return SizedBox(
      width: 210,
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
            Expanded(
              child: Column(
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
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget filters() {
    const values = <(String, String)>[
      ('pending', 'На проверке'),
      ('approved', 'Подтверждено'),
      ('returned', 'Возвращено'),
      ('all', 'Все'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((item) {
        return ChoiceChip(
          label: Text(item.$2),
          selected: filter == item.$1,
          onSelected: (_) => setState(() => filter = item.$1),
        );
      }).toList(growable: false),
    );
  }

  Widget reportCard(TaskCompletionReport item) {
    final details = <String>[
      if (item.objectName.trim().isNotEmpty) item.objectName.trim(),
      if (item.axes.trim().isNotEmpty) item.axes.trim(),
      if (item.workLocation.trim().isNotEmpty &&
          item.workLocation.trim() != item.axes.trim())
        item.workLocation.trim(),
    ].join(' · ');
    final color = statusColor(item);

    return PremiumPressable(
      onTap: item.isPending ? () => review(item) : null,
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
                        item.work.trim().isEmpty ? 'Выполненная работа' : item.work,
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
                            fontWeight: FontWeight.w650,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Text(
                    item.statusTitle,
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
            Row(
              children: [
                Expanded(
                  child: _FactValue(
                    label: item.isApproved ? 'Принято' : 'Заявлено мастером',
                    value: item.isApproved
                        ? item.approvedVolumeTitle
                        : item.reportedVolumeTitle,
                  ),
                ),
                Expanded(
                  child: _FactValue(
                    label: 'Мастер',
                    value: item.submittedByName.trim().isEmpty
                        ? 'Не указано'
                        : item.submittedByName,
                  ),
                ),
                Expanded(
                  child: _FactValue(
                    label: 'Передано',
                    value: dateTimeTitle(item.submittedAt),
                  ),
                ),
              ],
            ),
            if (item.completionComment.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                item.completionComment,
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.reviewComment.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${item.isReturned ? 'Причина возврата' : 'Комментарий сметчика'}: ${item.reviewComment}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (item.isPending) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => review(item),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Проверить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Инженер-сметчик',
      subtitle: 'Фактически выполненные работы от мастеров',
      child: FutureBuilder<List<TaskCompletionReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 42),
                  const SizedBox(height: 10),
                  const Text(
                    'Не удалось загрузить выполненные работы',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final all = snapshot.data ?? const <TaskCompletionReport>[];
          final items = visible(all);
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    metric(
                      icon: Icons.pending_actions_rounded,
                      label: 'На проверке',
                      value: count(all, 'pending'),
                    ),
                    metric(
                      icon: Icons.verified_outlined,
                      label: 'Подтверждено',
                      value: count(all, 'approved'),
                    ),
                    metric(
                      icon: Icons.reply_all_rounded,
                      label: 'Возвращено',
                      value: count(all, 'returned'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                filters(),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  PremiumWorkCard(
                    radius: 22,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 38,
                          color: AppAdaptivePalette.textMuted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          filter == 'pending'
                              ? 'Сейчас ничего не ждёт проверки'
                              : 'В этом разделе пока пусто',
                          style: TextStyle(
                            color: AppAdaptivePalette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: reportCard(item),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FactValue extends StatelessWidget {
  final String label;
  final String value;

  const _FactValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
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

class _EstimatorReviewDialog extends StatefulWidget {
  final TaskCompletionReport report;

  const _EstimatorReviewDialog({required this.report});

  @override
  State<_EstimatorReviewDialog> createState() => _EstimatorReviewDialogState();
}

class _EstimatorReviewDialogState extends State<_EstimatorReviewDialog> {
  late final TextEditingController quantityController;
  late final TextEditingController commentController;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    quantityController = TextEditingController(
      text: widget.report.reportedQuantity == null
          ? ''
          : TaskCompletionReport.formatQuantity(widget.report.reportedQuantity!),
    );
    commentController = TextEditingController();
  }

  @override
  void dispose() {
    quantityController.dispose();
    commentController.dispose();
    super.dispose();
  }

  double? parseQuantity() {
    final value = quantityController.text.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.'));
  }

  Future<void> approve() async {
    if (saving) return;
    final quantityText = quantityController.text.trim();
    final quantity = parseQuantity();
    if (quantityText.isNotEmpty && (quantity == null || quantity <= 0)) {
      setState(() => errorText = 'Укажите корректный подтверждённый объём');
      return;
    }
    await run(
      () => TaskCompletionReportRepository.approve(
        reportId: widget.report.id,
        approvedQuantity: quantity,
        comment: commentController.text,
      ),
    );
  }

  Future<void> returnToForeman() async {
    if (saving) return;
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

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => errorText = error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    return AlertDialog(
      title: const Text('Проверка выполненной работы'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                report.work,
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
                  fontWeight: FontWeight.w650,
                ),
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: _FactValue(
                        label: 'Мастер заявил',
                        value: report.reportedVolumeTitle,
                      ),
                    ),
                    Expanded(
                      child: _FactValue(
                        label: 'Мастер',
                        value: report.submittedByName.trim().isEmpty
                            ? 'Не указано'
                            : report.submittedByName,
                      ),
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
                  hintText: report.reportedQuantity == null
                      ? 'Можно оставить без объёма'
                      : null,
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
