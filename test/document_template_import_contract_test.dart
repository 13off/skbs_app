import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('external templates import DOCX before online editing', () {
    final source = File(
      'lib/features/documents/presentation/document_tool_templates_screen.dart',
    ).readAsStringSync();

    expect(source, contains('canEditOnlineVersion'));
    expect(source, contains('Загрузить DOCX в AppСтрой'));
    expect(source, contains('openEditorAfterUpload: true'));
    expect(source, contains('version.isAsset || version.isStorage'));
  });

  test('missing current HR forms have template slots', () {
    final migration = File(
      'supabase/migrations/20260803174500_add_current_hr_template_slots.sql',
    ).readAsStringSync();

    expect(migration, contains('termination_application'));
    expect(migration, contains('ticket_purchase_agreement'));
  });
}
