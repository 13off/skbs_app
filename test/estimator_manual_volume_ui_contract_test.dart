import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual estimator records remain auditable and reasoned', () {
    final source = File(
      'lib/features/estimator/presentation/estimator_manual_volumes_screen.dart',
    ).readAsStringSync();

    expect(source, contains("title: 'Ручные объёмы'"));
    expect(source, contains("label: const Text('Добавить объём')"));
    expect(source, contains("labelText: 'Причина ручного ввода'"));
    expect(source, contains("labelText: 'Пояснение'"));
    expect(source, contains("labelText: 'Причина аннулирования'"));
    expect(source, contains("label: const Text('Аннулировать')"));
    expect(source, contains("'Аннулировано'"));
    expect(source, contains('Активные ручные записи автоматически входят'));
    expect(source, isNot(contains('delete(')));
  });
}
