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
    const directSignals = <String>[
      'bottomNavigationBar:',
      'floatingActionButton:',
      'persistentFooterButtons:',
      'bottomSheet:',
      'Alignment.bottomCenter',
      'Alignment.bottomLeft',
      'Alignment.bottomRight',
    ];
    const interactiveSignals = <String>[
      'Button(',
      'IconButton(',
      'InkWell(',
      'GestureDetector(',
      'PremiumPressable(',
      'onTap:',
      'onPressed:',
    ];

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        final direct = directSignals.any(line.contains);
        final positioned = line.contains('Positioned(') ||
            line.contains('PositionedDirectional(');
        if (!direct && !positioned) continue;

        final end = index + 28 < lines.length ? index + 28 : lines.length - 1;
        final window = lines.sublist(index, end + 1).join('\n');
        final bottomInteractive = positioned &&
            window.contains('bottom:') &&
            interactiveSignals.any(window.contains);
        if (!direct && !bottomInteractive) continue;

        final snippetEnd = index + 12 < lines.length ? index + 12 : lines.length - 1;
        final snippet = lines
            .sublist(index, snippetEnd + 1)
            .map((value) => value.trim())
            .join(' ')
            .replaceAll(RegExp(r'\s+'), ' ');
        findings.add('${file.path}:${index + 1}: $snippet');
      }
    }

    fail('BUTTON_LAYOUT_INVENTORY (${findings.length})\n${findings.join('\n')}');
  });
}
