import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/estimator/models/estimator_manual_volume.dart';

EstimatorManualVolume record(String code) {
  final now = DateTime(2026, 9, 8);
  return EstimatorManualVolume(
    id: code,
    objectName: 'Мурманск',
    work: 'Работа',
    unit: 'м³',
    quantity: 1,
    workDate: now,
    reasonCode: code,
    reasonComment: 'Причина',
    createdByName: 'Сметчик',
    createdAt: now,
    voidedAt: null,
    voidedByName: '',
    voidReason: '',
  );
}

void main() {
  test('manual reason codes have stable Russian labels', () {
    expect(record('unplanned_work').reasonTitle, 'Дополнительная работа');
    expect(record('task_missing').reasonTitle, 'Работа без задачи');
    expect(record('correction').reasonTitle, 'Корректировка объёма');
    expect(record('carryover').reasonTitle, 'Перенос из другого периода');
    expect(record('other').reasonTitle, 'Другое');
  });
}
