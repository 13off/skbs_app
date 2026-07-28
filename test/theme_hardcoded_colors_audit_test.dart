import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audit hardcoded theme-sensitive colors in UI files', () {
    final roots = <Directory>[
      Directory('lib/screens'),
      Directory('lib/features'),
      Directory('lib/widgets'),
    ];
    final suspicious = <String>[];
    final namedPatterns = <RegExp>[
      RegExp(r'Colors\.white\b'),
      RegExp(r'Colors\.black\b'),
      RegExp(r'Colors\.grey(?:\.|\b)'),
      RegExp(r'Colors\.blueGrey(?:\.|\b)'),
    ];
    final literalPattern = RegExp(r'Color\(0x([0-9A-Fa-f]{8})\)');

    double brightness(String argbHex) {
      final value = int.parse(argbHex, radix: 16);
      final red = (value >> 16) & 0xff;
      final green = (value >> 8) & 0xff;
      final blue = value & 0xff;
      return (299 * red + 587 * green + 114 * blue) / 1000;
    }

    bool isThemeSensitiveLiteral(String argbHex) {
      final value = brightness(argbHex);
      return value <= 155 || value >= 205;
    }

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
          final hasNamedColor = namedPatterns.any(
            (pattern) => pattern.hasMatch(line),
          );
          final hasThemeSensitiveLiteral = literalPattern
              .allMatches(line)
              .any((match) => isThemeSensitiveLiteral(match.group(1)!));
          if (hasNamedColor || hasThemeSensitiveLiteral) {
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
