import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/task_completion_report_repository.dart';
import '../models/estimator_volume_summary.dart';
import '../models/task_completion_report.dart';

class EstimatorVolumesScreen extends StatefulWidget {
  const EstimatorVolumesScreen({super.key});

  @override
  State<EstimatorVolumesScreen> createState() => _EstimatorVolumesScreenState();
}

class _EstimatorVolumesScreenState extends State<EstimatorVolumesScreen> {
  late Future<List<TaskCompletionReport>> future;
  late DateTime period;
  String objectFilter = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    period = DateTime(now.year, now.month);
    future = TaskCompletionReportRepository.fetchQueue(status: 'approved');
  }

  Future<void> refresh() async {
    final next = TaskCompletionReportRepository.fetchQueue(status: 'approved');
    setState(() => future = next);
    await next;
  }

  DateTime get nextPeriodStart => DateTime(period.year, period.month + 1);

  bool get canGoNext {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    return period.isBefore(current);
  }

  String get periodTitle {
    const months = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь',
    ];
    return '${months[period.month - 1]} ${period.year}';
  }

  void shiftPeriod(int months) {
    setState(() {
      period = DateTime(period.year, period.month + months);
    });
  }

  List<String> objectNames(List<TaskCompletionReport> reports) {
    final values = reports
        .where((report) => report.isApproved)
        .map(
          (report) => report.objectName.trim().isEmpty
              ? 'Без объекта'
              : report.objectName.trim(),
        )
        .toSet()
        .toList(growable: false);
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  bool matchesObject(TaskCompletionReport report) {
    if (objectFilter.isEmpty) return true;
    final objectName = report.objectName.trim().isEmpty
        ? 'Без объекта'
        : report.objectName.trim();
    return objectName.toLowerCase() == objectFilter.toLowerCase();
  }

  List<TaskCompletionReport> sourceReports(List<TaskCompletionReport> reports) {
    return reports
        .where(
          (report) =>
              report.isApproved &&
              report.approvedQuantity != null &&
              report.taskDate.isBefore(nextPeriodStart) &&
              matchesObject(report),
        )
        .toList(growable: false);
  }

  int withoutVolumeCount(List<TaskCompletionReport> reports) {
    return reports
        .where(
          (report) =>
              report.isApproved &&
              report.approvedQuantity == null &&
              report.taskDate.isBefore(nextPeriodStart) &&
              matchesObject(report),
        )
        .length;
  }

  int objectCount(List<TaskCompletionReport> reports) {
    return sourceReports(reports)
        .map(
          (report) => report.objectName.trim().isEmpty
              ? 'Без объекта'
              : report.objectName.trim().toLowerCase(),
        )
        .toSet()
        .length;
  }

  Widget metric(String label, int value, IconData icon) {
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
                  label,
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

  Widget controls(List<String> objects) {
    if (objectFilter.isNotEmpty && !objects.contains(objectFilter)) {
      objectFilter = '';
    }
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.filledTonal(
                tooltip: 'Предыдущий месяц',
                onPressed: () => shiftPeriod(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              SizedBox(
                width: 170,
                child: Text(
                  periodTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Следующий месяц',
                onPressed: canGoNext ? () => shiftPeriod(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          SizedBox(
            width: 310,
            child: DropdownButtonFormField<String>(
              value: objectFilter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Объект',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Все объекты'),
                ),
                ...objects.map(
                  (object) => DropdownMenuItem<String>(
                    value: object,
                    child: Text(
                      object,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => objectFilter = value ?? '');
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppAdaptivePalette.textMuted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ведомость собирается автоматически только из подтверждённых работ. '
              'Сейчас позиции группируются по объекту, названию работы и единице измерения. '
              'После импорта сметы привяжем их к конкретным позициям сметы.',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openSummary(EstimatorVolumeSummary summary) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _VolumeSourcesDialog(summary: summary, period: period),
    );
  }

  Widget desktopTable(List<EstimatorVolumeSummary> summaries) {
    return PremiumWorkCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _VolumeTableRow(
            header: true,
            work: 'Работа',
            unit: 'Ед.',
            previous: 'Ранее',
            period: 'За период',
            total: 'Всего',
            sources: 'Источников',
          ),
          for (var index = 0; index < summaries.length; index++) ...[
            if (index > 0)
              Divider(height: 1, color: AppAdaptivePalette.border),
            _VolumeTableRow(
              work: summaries[index].work,
              objectName: objectFilter.isEmpty
                  ? summaries[index].objectName
                  : '',
              unit: summaries[index].unit,
              previous: summaries[index].previousTitle,
              period: summaries[index].periodTitle,
              total: summaries[index].totalTitle,
              sources: '${summaries[index].sourceCount}',
              onTap: () => openSummary(summaries[index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget mobileCards(List<EstimatorVolumeSummary> summaries) {
    return Column(
      children: summaries
          .map(
            (summary) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumPressable(
                onTap: () => openSummary(summary),
                borderRadius: BorderRadius.circular(22),
                child: PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.work,
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${summary.objectName} · ${summary.unit}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _SmallFact(label: 'Ранее', value: summary.previousTitle),
                          _SmallFact(label: 'За период', value: summary.periodTitle),
                          _SmallFact(label: 'Всего', value: summary.totalTitle),
                          _SmallFact(
                            label: 'Источников',
                            value: '${summary.sourceCount}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppPage.desktopBreakpoint;
    return AppPage(
      title: 'Объёмы',
      subtitle: 'Накопительная ведомость подтверждённых работ',
      onRefresh: refresh,
      child: FutureBuilder<List<TaskCompletionReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 220,
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Не удалось загрузить объёмы · Повторить'),
                ),
              ),
            );
          }

          final reports = snapshot.data ?? const <TaskCompletionReport>[];
          final objects = objectNames(reports);
          final summaries = EstimatorVolumeSummary.build(
            reports: reports,
            period: period,
            objectFilter: objectFilter,
          );
          final sources = sourceReports(reports);
          final withoutVolume = withoutVolumeCount(reports);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controls(objects),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  metric('Позиций', summaries.length, Icons.table_rows_rounded),
                  metric('Работ-источников', sources.length, Icons.task_alt_rounded),
                  metric('Объектов', objectCount(reports), Icons.apartment_rounded),
                  metric(
                    'Без объёма',
                    withoutVolume,
                    Icons.warning_amber_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              infoCard(),
              const SizedBox(height: 14),
              if (summaries.isEmpty)
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(26),
                  child: Center(
                    child: Text(
                      'Подтверждённых объёмов за этот период пока нет',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else if (isDesktop)
                desktopTable(summaries)
              else
                mobileCards(summaries),
            ],
          );
        },
      ),
    );
  }
}

class _VolumeTableRow extends StatelessWidget {
  final bool header;
  final String work;
  final String objectName;
  final String unit;
  final String previous;
  final String period;
  final String total;
  final String sources;
  final VoidCallback? onTap;

  const _VolumeTableRow({
    this.header = false,
    required this.work,
    this.objectName = '',
    required this.unit,
    required this.previous,
    required this.period,
    required this.total,
    required this.sources,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: header
          ? AppAdaptivePalette.textMuted
          : AppAdaptivePalette.textPrimary,
      fontSize: header ? 11 : 13,
      fontWeight: header ? FontWeight.w800 : FontWeight.w700,
    );

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 18,
        vertical: header ? 12 : 15,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(work, style: textStyle),
                if (!header && objectName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    objectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(flex: 1, child: Text(unit, style: textStyle)),
          Expanded(flex: 2, child: Text(previous, style: textStyle)),
          Expanded(flex: 2, child: Text(period, style: textStyle)),
          Expanded(
            flex: 2,
            child: Text(
              total,
              style: textStyle.copyWith(
                fontWeight: header ? FontWeight.w800 : FontWeight.w900,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(sources, style: textStyle)),
          if (!header)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppAdaptivePalette.textMuted,
            ),
        ],
      ),
    );

    if (header || onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _SmallFact extends StatelessWidget {
  final String label;
  final String value;

  const _SmallFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppAdaptivePalette.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppAdaptivePalette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _VolumeSourcesDialog extends StatelessWidget {
  final EstimatorVolumeSummary summary;
  final DateTime period;

  const _VolumeSourcesDialog({required this.summary, required this.period});

  String dateTitle(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final periodStart = DateTime(period.year, period.month);
    final sources = [...summary.sources]
      ..sort((a, b) => b.taskDate.compareTo(a.taskDate));
    return AlertDialog(
      title: Text(summary.work),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${summary.objectName} · ${summary.unit}',
                style: TextStyle(
                  color: AppAdaptivePalette.textMuted,
                  fontWeight: FontWeight.w700,
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
                    _SmallFact(label: 'Ранее', value: summary.previousTitle),
                    _SmallFact(label: 'За период', value: summary.periodTitle),
                    _SmallFact(label: 'Всего', value: summary.totalTitle),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Из каких работ сложился объём',
                style: TextStyle(
                  color: AppAdaptivePalette.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < sources.length; index++) ...[
                if (index > 0)
                  Divider(height: 1, color: AppAdaptivePalette.border),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.surfaceSoft,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          sources[index].taskDate.isBefore(periodStart)
                              ? 'Ранее'
                              : 'Период',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [sources[index].axes, sources[index].workLocation]
                                  .where((value) => value.trim().isNotEmpty)
                                  .toSet()
                                  .join(' · '),
                              style: TextStyle(
                                color: AppAdaptivePalette.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${dateTitle(sources[index].taskDate)} · ${sources[index].submittedByName.isEmpty ? 'Мастер не указан' : sources[index].submittedByName}',
                              style: TextStyle(
                                color: AppAdaptivePalette.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${TaskCompletionReport.formatQuantity(sources[index].approvedQuantity!)} ${summary.unit}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
