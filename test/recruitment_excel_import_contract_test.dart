import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'candidate Excel import has mapping preview duplicate protection and template',
    () {
      final source = File(
        'lib/features/recruitment/presentation/recruitment_import_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Excel.decodeBytes'));
      expect(source, contains('Сопоставьте столбцы'));
      expect(source, contains('Предпросмотр'));
      expect(source, contains('phoneKey'));
      expect(source, contains('дубль телефона'));
      expect(source, contains('Шаблон_импорта_кандидатов'));
      expect(source, contains("source: 'excel_import'"));
      expect(source, contains('runAutomations'));
    },
  );
}
