import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('длинные списки отчётов не разворачиваются на общем экране', () {
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();
    final weekly = File(
      'lib/features/reports/presentation/manager_weekly_contribution_section.dart',
    ).readAsStringSync();

    expect(sections, contains('class _ManagerReportSectionScreen'));
    expect(sections, contains('class _DispatcherReportsScreen'));
    expect(sections, contains("label: const Text('Открыть сводку')"));
    expect(
      sections,
      contains("label: const Text('Открыть оперативные сводки')"),
    );
    expect(sections, contains("openLabel: 'Открыть табель'"));
    expect(sections, contains("secondaryLabel: 'Отчёт за период'"));
    expect(sections, contains("openLabel: 'Открыть бухгалтерские отчёты'"));
    expect(sections, contains('CupertinoPageRoute<void>'));

    expect(weekly, contains('class _WeeklyContributionDetailsScreen'));
    expect(weekly, contains("label: const Text('Открыть недельную сводку')"));
    expect(weekly, isNot(contains('initiallyExpanded: true')));
  });

  test('основные действия находятся до подробного списка', () {
    final sections = File(
      'lib/features/reports/presentation/manager_report_sections.dart',
    ).readAsStringSync();

    final actionIndex = sections.indexOf('if (onOpen != null || onSecondary != null)');
    final detailsIndex = sections.indexOf("Text(\n            'Подробности'");

    expect(actionIndex, greaterThanOrEqualTo(0));
    expect(detailsIndex, greaterThan(actionIndex));
  });
}
