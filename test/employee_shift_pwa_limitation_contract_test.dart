import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA не обещает фоновую запись маршрута', () {
    final service = File(
      'lib/features/employee/data/employee_shift_tracking_service.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/employee/presentation/employee_work_cabinet_screen.dart',
    ).readAsStringSync();

    expect(service, contains("'web_foreground'"));
    expect(service, contains('Не закрывайте браузер'));
    expect(
      screen,
      contains('PWA не может гарантировать запись после сворачивания'),
    );
    expect(screen, contains('установленное приложение'));
  });
}
