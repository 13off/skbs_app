import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Точка штатной Web/PWA-публикации компактного центра отчётов.
void main() {
  test('длинные списки отчётов не разворачиваются на общем экране', () {
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final weekly = File(
      'lib/features/reports/presentation/manager_weekly_contribution_section.dart',
    ).readAsStringSync();
    final tile = File(
      'lib/features/reports/presentation/manager_report_tile.dart',
    ).readAsStringSync();

    expect(sections, contains('class _ManagerReportSectionScreen'));
    expect(sections, contains('class _DispatcherReportsScreen'));
    expect(sections, contains('ManagerReportTile('));
    expect(sections, isNot(contains("label: const Text('Открыть сводку')")));
    expect(
      sections,
      isNot(contains("label: const Text('Открыть оперативные сводки')")),
    );
    expect(sections, contains("openLabel: 'Открыть табель'"));
    expect(sections, contains("secondaryLabel: 'Отчёт за период'"));
    expect(sections, contains("openLabel: 'Открыть бухгалтерию'"));
    expect(sections, contains('AppPageRoute<void>'));
    expect(tile, contains('onTap: loading ? null : onTap'));

    expect(weekly, contains('class _WeeklyContributionDetailsScreen'));
    expect(weekly, contains('ManagerReportTile('));
    expect(
      weekly,
      isNot(contains("label: const Text('Открыть недельную сводку')")),
    );
    expect(weekly, isNot(contains('initiallyExpanded: true')));
  });

  test('основные действия находятся до подробного списка', () {
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();

    final actionIndex = sections.indexOf(
      'if (onOpen != null || onSecondary != null)',
    );
    final detailsIndex = sections.indexOf("'Подробности'");

    expect(actionIndex, greaterThanOrEqualTo(0));
    expect(detailsIndex, greaterThan(actionIndex));
  });
}
