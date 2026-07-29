import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('what is new uses an animated, navigable presentation', () {
    final source = File(
      'lib/features/whats_new/presentation/whats_new_gate.dart',
    ).readAsStringSync();

    expect(source, contains('PageView.builder'));
    expect(source, contains('Icons.arrow_back_rounded'));
    expect(source, contains('Icons.arrow_forward_rounded'));
    expect(source, contains('_EmployeeCabinetDemo'));
    expect(source, contains('_ReportPagesDemo'));
    expect(source, contains('_ThemeToggleDemo'));
    expect(source, contains('_KpiSliderDemo'));
    expect(source, contains('disableAnimations'));
    expect(source, contains('mobile-2026-07-29-animated-whats-new'));
  });
}
