import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit hardcoded light and dark colors in UI files', () {
    final roots = <Directory>[
      Directory('lib/screens'),
      Directory('lib/features'),
      Directory('lib/widgets'),
    ];
    final suspicious = <String>[];
    final patterns = <RegExp>[
      RegExp(r'Colors\.white\b'),
      RegExp(r'Colors\.black\b'),
      RegExp(r'Colors\.grey(?:\.|\b)'),
      RegExp(r'Colors\.blueGrey(?:\.|\b)'),
      RegExp(r'Color\(0x[Ff][Ff][EeFf][EeFf][EeFf][EeFf][EeFf][EeFf]\)'),
    ];

    for (final root in roots) {
      if (!root.existsSync()) continue;
      final files = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index++) {
          final line = lines[index];
          if (patterns.any((pattern) => pattern.hasMatch(line))) {
            suspicious.add('${file.path}:${index + 1}: ${line.trim()}');
          }
        }
      }
    }

    if (suspicious.isNotEmpty) {
      fail(
        'Найдены жёстко заданные цвета интерфейса (${suspicious.length}):\n'
        '${suspicious.join('\n')}',
      );
    }
  });
}
