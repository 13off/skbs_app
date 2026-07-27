import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/task_contribution_repository.dart';
import '../../../models/employee.dart';

class EmployeeContributionScreen extends StatefulWidget {
  final Employee employee;

  const EmployeeContributionScreen({super.key, required this.employee});

  @override
  State<EmployeeContributionScreen> createState() =>
      _EmployeeContributionScreenState();
}

enum _ContributionPeriod { week, month, shift, custom }

class _EmployeeContributionScreenState
    extends State<EmployeeContributionScreen> {
  _ContributionPeriod period = _ContributionPeriod.month;
  DateTimeRange? customRange;
  late Future<EmployeeContributionSummary> summaryFuture;

  String get employeeId => widget.employee.id?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    summaryFuture = loadSummary();
  }

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTimeRange? get activeRange {
    switch (period) {
      case _ContributionPeriod.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case _ContributionPeriod.month:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: today,
        );
      case _ContributionPeriod.shift:
        return null;
      case _ContributionPeriod.custom:
        return customRange;
    }
  }

  Future<EmployeeContributionSummary> loadSummary() {
    if (employeeId.isEmpty) {
      return Future<EmployeeContributionSummary>.value(
        const EmployeeContributionSummary.empty(),
      );
    }
    final range = activeRange;
    return TaskContributionRepository.fetchEmployeeSummary(
      employeeId: employeeId,
      dateFrom: range?.start,
      dateTo: range?.end,
    );
  }

  void reload() {
    setState(() => summaryFuture = loadSummary());
  }

  Future<void> selectPeriod(_ContributionPeriod next) async {
    if (next == _ContributionPeriod.custom) {
      final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: DateTime(2035),
        initialDateRange: customRange,
        helpText: 'Период личного вклада',
        saveText: 'Выбрать',
      );
      if (!mounted || selected == null) return;
      customRange = selected;
    }
    period = next;
    reload();
  }

  String periodTitle() {
    final range = activeRange;
    if (period == _ContributionPeriod.shift) {
      return 'Весь сохранённый период работы на объекте';
    }
    if (range == null) return 'Период не выбран';
    final format = DateFormat('dd.MM.yyyy');
    return '${format.format(range.start)} — ${format.format(range.end)}';
  }

  String number(double value) {
    return NumberFormat('0.##', 'ru_RU').format(value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личный вклад'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<EmployeeContributionSummary>(
        future: summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: reload,
            );
          }
          final summary = snapshot.data ??
              const EmployeeContributionSummary.empty();
          return RefreshIndicator(
            onRefresh: () async {
              reload();
              await summaryFuture;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                Text(
                  widget.employee.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Доля сотрудника в завершённых задачах · ${widget.employee.objectName}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _periodChip('Неделя', _ContributionPeriod.week),
                    _periodChip('Месяц', _ContributionPeriod.month),
                    _periodChip('Вахта', _ContributionPeriod.shift),
                    _periodChip('Период', _ContributionPeriod.custom),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  periodTitle(),
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 780 ? 4 : 2;
                    final spacing = 10.0;
                    final width =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        _MetricCard(
                          width: width,
                          title: 'Участие',
                          value: '${summary.taskCount}',
                          subtitle: 'завершённых задач',
                          icon: Icons.task_alt_rounded,
                        ),
                        _MetricCard(
                          width: width,
                          title: 'Личный вклад',
                          value: number(summary.equivalentTasks),
                          subtitle: 'условной задачи',
                          icon: Icons.percent_rounded,
                        ),
                        _MetricCard(
                          width: width,
                          title: 'Средняя доля',
                          value: '${number(summary.averagePercent)}%',
                          subtitle: 'в своих задачах',
                          icon: Icons.balance_rounded,
                        ),
                        _MetricCard(
                          width: width,
                          title: 'Доля результата',
                          value: '${number(summary.objectSharePercent)}%',
                          subtitle:
                              'из ${summary.objectTaskCount} задач объекта',
                          icon: Icons.pie_chart_outline_rounded,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'История задач',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (summary.history.isEmpty)
                  _EmptyState(periodTitle: periodTitle())
                else
                  ...summary.history.map(
                    (row) => _HistoryCard(row: row),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _periodChip(String label, _ContributionPeriod value) {
    return ChoiceChip(
      label: Text(label),
      selected: period == value,
      onSelected: (_) => selectPeriod(value),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 19, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final EmployeeContributionHistoryRow row;

  const _HistoryCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <String>[
      DateFormat('dd.MM.yyyy').format(row.date),
      if (row.objectName.isNotEmpty) row.objectName,
      if (row.axes.isNotEmpty) 'Оси: ${row.axes}',
    ].join(' · ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        minVerticalPadding: 13,
        title: Text(
          row.work.isEmpty ? 'Задача' : row.work,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          details,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '${row.percent}%',
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String periodTitle;

  const _EmptyState({required this.periodTitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.donut_large_rounded,
              size: 42,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'Вклад пока не зафиксирован',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              'За период $periodTitle нет завершённых задач с распределённым вкладом.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 10),
            const Text(
              'Не удалось загрузить личный вклад',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
