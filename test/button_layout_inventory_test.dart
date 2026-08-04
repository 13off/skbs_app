import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inventory fixed and bottom action controls', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final findings = <String>[];
    const signals = <String>[
      'bottomNavigationBar:',
      'floatingActionButton:',
      'Positioned(',
      'PositionedDirectional(',
      'SafeArea(',
      'persistentFooterButtons:',
      'bottomSheet:',
    ];

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (!signals.any(line.contains)) continue;

        final start = index > 1 ? index - 1 : 0;
        final end = index + 8 < lines.length ? index + 8 : lines.length - 1;
        final snippet = lines
            .sublist(start, end + 1)
            .map((value) => value.trim())
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        findings.add('${file.path}:${index + 1}: $snippet');
      }
    }

    // ignore: avoid_print
    print('BUTTON_LAYOUT_INVENTORY_START');
    for (final finding in findings) {
      // ignore: avoid_print
      print(finding);
    }
    // ignore: avoid_print
    print('BUTTON_LAYOUT_INVENTORY_END (${findings.length})');

    expect(findings, isNotEmpty);
  });
}
