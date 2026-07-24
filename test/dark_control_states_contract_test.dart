import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selected timesheet shifts use the blue accent', () {
    final source = File(
      'lib/screens/desktop_timesheet_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('color: selected ? AppAdaptivePalette.accentStrong : _soft'),
    );
    expect(
      source,
      contains('color: selected ? AppAdaptivePalette.accent : _line'),
    );
    expect(source, isNot(contains('color: selected ? _text : _soft')));
  });

  test('foreman date and notification button use dark surfaces', () {
    final dateSource = File(
      'lib/features/foreman/presentation/foreman_home_summary_widgets.dart',
    ).readAsStringSync();
    final bellSource = File(
      'lib/widgets/notification_bell.dart',
    ).readAsStringSync();

    expect(dateSource, contains('color: AppAdaptivePalette.surfaceElevated'));
    expect(dateSource, isNot(contains('color: Colors.white,')));

    expect(bellSource, contains('? AppAdaptivePalette.accentSoft'));
    expect(bellSource, contains(': _card,'));
    expect(bellSource, contains('hasUnread ? _accent : _line'));
    expect(
      bellSource,
      isNot(contains('Colors.white.withValues(alpha: 0.96)')),
    );
  });

  test('selected HR filters use the blue accent', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ).readAsStringSync();

    expect(source, contains('selectedColor: AppAdaptivePalette.accentStrong'));
    expect(source, isNot(contains('selectedColor: _text')));
  });

  test('legacy white selected-surface patterns do not return', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    const forbidden = <String>[
      'selectedColor: _text',
      'color: selected ? _text : _soft',
      'border: Border.all(color: selected ? _text : _line)',
    ];

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final pattern in forbidden) {
        expect(source, isNot(contains(pattern)), reason: '${file.path}: $pattern');
      }
    }
  });

  test('control-state patch remains presentation-only', () {
    const dataAccessPatterns = <String>[
      'Supabase.instance',
      '.from(',
      '.rpc(',
      '.functions.invoke(',
      '.storage.from(',
    ];
    for (final path in <String>[
      'lib/screens/desktop_timesheet_screen.dart',
      'lib/features/foreman/presentation/foreman_home_summary_widgets.dart',
      'lib/widgets/notification_bell.dart',
      'lib/features/recruitment/presentation/recruitment_applications_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')), reason: path);
      for (final pattern in dataAccessPatterns) {
        expect(source, isNot(contains(pattern)), reason: '$path: $pattern');
      }
    }
  });
}
