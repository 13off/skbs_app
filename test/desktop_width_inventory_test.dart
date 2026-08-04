import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory desktop width constraints', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final findings = <String>[];
    const signals = <String>[
      'maxWidth:',
      'pageContentWidth',
      'specialistContentWidth',
      'desktopContentWidth',
    ];

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!signals.any(lines[index].contains)) continue;
        final start = index > 2 ? index - 2 : 0;
        final end = index + 5 < lines.length ? index + 5 : lines.length - 1;
        final snippet = lines
            .sublist(start, end + 1)
            .map((line) => line.trim())
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        findings.add('${file.path}:${index + 1}: $snippet');
      }
    }

    fail('DESKTOP_WIDTH_INVENTORY (${findings.length})\n${findings.join('\n')}');
  });
}
