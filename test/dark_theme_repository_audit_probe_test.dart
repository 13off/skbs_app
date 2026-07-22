import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('temporary repository dark-theme audit probe', () {
    const ignoredPaths = <String>{
      'lib/app/app_theme.dart',
      'lib/widgets/premium_ui.dart',
      'lib/features/theme/data/app_theme_repository.dart',
    };
    const patterns = <String>[
      'Colors.white',
      'Color(0xFFFF',
      'Color(0xFFFE',
      'Color(0xFFFD',
      'Color(0xFFFC',
      'Color(0xFFFB',
      'Color(0xFFFA',
      'Color(0xFFF9',
      'Color(0xFFF8',
      'Color(0xFFF7',
      'Color(0xFFF6',
      'Color(0xFFF5',
      'Color(0xFFF4',
      'Color(0xFFF3',
      'Color(0xFFF2',
      'Color(0xFFF1',
      'Color(0xFFF0',
      'AppColors.textPrimary',
      'AppColors.textMuted',
      'AppColors.surfaceSoft',
      'AppColors.border',
    ];

    final findings = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (ignoredPaths.contains(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (patterns.any(line.contains)) {
          findings.add('$path:${index + 1}: ${line.trim()}');
        }
      }
    }

    if (findings.isNotEmpty) {
      fail('DARK_THEME_AUDIT_FINDINGS\n${findings.join('\n')}');
    }
  });
}
