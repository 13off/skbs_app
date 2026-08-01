import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('центр отчётов использует единые компактные карточки', () {
    final screen = File(
      'lib/features/reports/presentation/manager_reports_screen.dart',
    ).readAsStringSync();
    final header = File(
      'lib/features/reports/presentation/manager_report_header_widgets.dart',
    ).readAsStringSync();
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();
    final weekly = File(
      'lib/features/reports/presentation/manager_weekly_contribution_section.dart',
    ).readAsStringSync();
    final tile = File(
      'lib/features/reports/presentation/manager_report_tile.dart',
    ).readAsStringSync();

    expect(screen, contains("'Быстрые отчёты'"));
    expect(screen, contains('ManagerReportTile'));
    expect(screen, isNot(contains('ManagerDailyAiReviewCard')));
    expect(header, isNot(contains('Сейчас:')));
    expect(sections, contains('ManagerReportTile'));
    expect(weekly, contains('ManagerReportTile'));
    expect(tile, contains('InkWell'));
    expect(tile, contains('arrow_forward_ios_rounded'));

    expect(
      sections,
      isNot(contains(
        'Выберите раздел. Длинные списки открываются на отдельной странице.',
      )),
    );
    expect(sections, isNot(contains("label: const Text('Открыть сводку')")));
    expect(
      sections,
      isNot(contains("label: const Text('Открыть оперативные сводки')")),
    );
    expect(
      weekly,
      isNot(contains("label: const Text('Открыть недельную сводку')")),
    );
  });
}
