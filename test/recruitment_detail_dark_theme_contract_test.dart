import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('candidate detail uses adaptive documents chat and messages', () {
    final screen = File(
      'lib/features/recruitment/presentation/recruitment_application_detail_screen.dart',
    ).readAsStringSync();

    expect(screen, contains('AppAdaptivePalette.surfaceElevated'));
    expect(screen, contains('AppAdaptivePalette.surfaceSoft'));
    expect(screen, contains('AppAdaptivePalette.inputSurface'));
    expect(screen, contains('AppAdaptivePalette.selectedSurface'));
    expect(screen, contains('AppAdaptivePalette.border'));
    expect(screen, contains('AppAdaptivePalette.warning'));
    expect(screen, contains('AppAdaptivePalette.success'));

    expect(screen, contains('RecruitmentRepository.fetchDocuments('));
    expect(screen, contains('RecruitmentRepository.fetchMessages('));
    expect(screen, contains('RecruitmentRepository.sendMessage('));
    expect(screen, contains('RecruitmentRepository.downloadStoredFile('));
    expect(screen, contains("label: const Text('Позвонить')"));
    expect(screen, contains("label: const Text('Копировать номер')"));
    expect(screen, contains("label: const Text('Открыть')"));
    expect(screen, contains("label: const Text('Скачать')"));

    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.78)')));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.72)')));
    expect(screen, isNot(contains('Colors.white.withValues(alpha: 0.70)')));
    expect(screen, isNot(contains('Color(0xFFE9EDF1)')));
    expect(screen, isNot(contains('Color(0xFFF3F5F7)')));
    expect(
      screen,
      isNot(contains('color: inbound ? Colors.white : const Color(0xFFDCEEFF)')),
    );
  });
}
