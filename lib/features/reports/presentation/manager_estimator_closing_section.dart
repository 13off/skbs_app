import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../../estimator/data/estimator_closing_operations_repository.dart';
import '../../estimator/models/estimator_closing_operations.dart';

class ManagerEstimatorClosingSection extends StatefulWidget {
  final int year;
  final int month;
  final String? objectId;

  const ManagerEstimatorClosingSection({
    super.key,
    required this.year,
    required this.month,
    required this.objectId,
  });

  @override
  State<ManagerEstimatorClosingSection> createState() => _ManagerEstimatorClosingSectionState();
}

class _ManagerEstimatorClosingSectionState extends State<ManagerEstimatorClosingSection> {
  late Future<EstimatorClosingDashboard> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void didUpdateWidget(covariant ManagerEstimatorClosingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month || oldWidget.objectId != widget.objectId) {
      future = load();
    }
  }

  Future<EstimatorClosingDashboard> load() {
    return EstimatorClosingOperationsRepository.fetchDashboard(
      year: widget.year,
      month: widget.month,
      objectId: widget.objectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EstimatorClosingDashboard>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(18),
            child: Text('Закрытие объёмов: данные временно недоступны · ${snapshot.error}'),
          );
        }
        final data = snapshot.data!;
        return PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Закрытие объёмов · ${data.month.toString().padLeft(2, '0')}.${data.year}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(_money(data.internalEarnings), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Metric('Закрытий', data.closings),
                  _Metric('Позиций', data.items),
                  _Metric('На проверке', data.inReview),
                  _Metric('К заказчику', data.waitingClient),
                  _Metric('Ждут оплаты', data.waitingPayment),
                  _Metric('Оплачено', data.paid),
                  _Metric('Возвраты', data.returned),
                  _Metric('Вопросы расчёта', data.earningIssues),
                ],
              ),
              if (data.manualItems > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Ручных позиций: ${data.manualItems}. Они не получают автоматическое распределение заработка.',
                  style: TextStyle(color: AppAdaptivePalette.textMuted),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Физические объёмы разных единиц измерения здесь не суммируются в одну цифру.',
                style: TextStyle(color: AppAdaptivePalette.textMuted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;
  const _Metric(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: const TextStyle(fontWeight: FontWeight.w700));
  }
}

String _money(double value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(raw[i]);
  }
  return '${buffer.toString()} ₽';
}
