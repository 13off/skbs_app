import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('money inputs accept decimal point or comma across core workflows', () {
    final formatter = File(
      'lib/widgets/app_input_formatters.dart',
    ).readAsStringSync();
    final payments = File(
      'lib/screens/add_payment_screen.dart',
    ).readAsStringSync();
    final expenses = File(
      'lib/features/expenses/presentation/expenses_screen.dart',
    ).readAsStringSync();
    final accounting = File(
      'lib/features/accounting/presentation/accounting_control_screen.dart',
    ).readAsStringSync();
    final accountingDocuments = File(
      'lib/features/accounting/presentation/accounting_documents_screen.dart',
    ).readAsStringSync();
    final legal = File(
      'lib/features/legal/presentation/legal_matter_editor_part.dart',
    ).readAsStringSync();
    final legalBase = File(
      'lib/features/legal/presentation/legal_base_complete_screen.dart',
    ).readAsStringSync();
    final procurement = File(
      'lib/features/procurement/presentation/procurement_request_editor_screen.dart',
    ).readAsStringSync();
    final executive = File(
      'lib/features/executive/presentation/executive_main_screen.dart',
    ).readAsStringSync();
    final aiPayment = File(
      'lib/features/ai/presentation/ai_payment_draft_screen.dart',
    ).readAsStringSync();

    expect(formatter, contains("final separator = dotIndex > commaIndex ? '.' : ',';"));
    expect(formatter, contains("replaceAll(',', '.')"));

    for (final source in <String>[
      payments,
      expenses,
      accounting,
      accountingDocuments,
      legal,
      legalBase,
      procurement,
      executive,
      aiPayment,
    ]) {
      expect(
        source,
        contains('AppInputFormatters.groupedNumber'),
        reason: 'A money-entry workflow bypasses the shared decimal formatter',
      );
    }

    expect(
      payments,
      contains('TextInputType.numberWithOptions(\n              decimal: true,'),
    );
    expect(
      legalBase,
      contains('TextInputType.numberWithOptions(\n                      decimal: true,'),
    );
    expect(
      executive,
      contains('inputFormatters: AppInputFormatters.groupedNumber'),
    );
  });
}
