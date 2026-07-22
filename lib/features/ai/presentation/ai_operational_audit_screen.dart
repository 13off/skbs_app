import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../screens/payments_screen.dart';
import '../../../screens/period_timesheet_screen.dart';
import '../models/ai_assistant_result.dart';

class AiOperationalAuditScreen extends StatelessWidget {
  final AiAssistantAction action;

  const AiOperationalAuditScreen({super.key, required this.action});

  List<Map<String, dynamic>> get issues {
    final value = action.payload['issues'];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  DateTime? get month {
    final value = action.text('month');
    final match = RegExp(r'^(20\d{2})-(0[1-9]|1[0-2])$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      1,
    );
  }

  String get objectName => action.text('object_name');

  String categoryTitle(String value) {
    return switch (value) {
      'attendance' => 'Табель',
      'payments' => 'Выплаты',
      'objects' => 'Объекты',
      _ => 'Контроль',
    };
  }

  IconData categoryIcon(String value) {
    return switch (value) {
      'attendance' => Icons.calendar_month_outlined,
      'payments' => Icons.payments_outlined,
      'objects' => Icons.apartment_outlined,
      _ => Icons.rule_outlined,
    };
  }

  Color severityColor(BuildContext context, String severity) {
    return severity == 'critical'
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF8A6418);
  }

  Future<void> openTimesheet(BuildContext context) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PeriodTimesheetScreen(
          selectedObjectName: objectName.isEmpty ? null : objectName,
          initialMonth: month,
        ),
      ),
    );
  }

  Future<void> openPayments(BuildContext context) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => PaymentsScreen(
          selectedObjectName: objectName.isEmpty ? null : objectName,
        ),
      ),
    );
  }

  Widget summaryCard(BuildContext context) {
    final critical = action.number('critical_count').round();
    final attention = action.number('attention_count').round();
    final attendance = action.number('attendance_count').round();
    final payments = action.number('payment_count').round();
    final objects = action.number('object_count').round();

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              issues.isEmpty
                  ? 'Явных проблем не найдено'
                  : 'Контрольных вопросов: ${issues.length}',
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('Период: ${action.text('month')}'),
            Text(
              objectName.isEmpty
                  ? 'Область: все доступные объекты'
                  : 'Объект: $objectName',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Критичные', value: critical),
                _Metric(label: 'Внимание', value: attention),
                _Metric(label: 'Табель', value: attendance),
                _Metric(label: 'Выплаты', value: payments),
                _Metric(label: 'Объекты', value: objects),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget issueCard(BuildContext context, Map<String, dynamic> issue) {
    final category = issue['category']?.toString() ?? '';
    final severity = issue['severity']?.toString() ?? 'attention';
    final employee = issue['employee_name']?.toString().trim() ?? '';
    final object = issue['object_name']?.toString().trim() ?? '';
    final message = issue['message']?.toString().trim() ?? '';
    final color = severityColor(context, severity);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(categoryIcon(category), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.isEmpty ? categoryTitle(category) : employee,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      if (object.isNotEmpty)
                        Text(
                          object,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 5),
                      Text(message),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: category == 'payments'
                    ? () => openPayments(context)
                    : () => openTimesheet(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  category == 'payments' ? 'Открыть выплаты' : 'Открыть табель',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Контроль табеля и выплат')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          summaryCard(context),
          const SizedBox(height: 14),
          if (issues.isEmpty)
            const Card(
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'По доступным данным явных технических несоответствий не найдено. '
                  'Плановый график и изменения ставки внутри месяца всё равно нужно проверять вручную.',
                ),
              ),
            )
          else
            ...issues.map((issue) => issueCard(context, issue)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Отчёт ничего не исправляет автоматически. Пустой табель считается '
                'контрольным вопросом, а сравнение начислений использует текущую ставку карточки.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Проверено'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
