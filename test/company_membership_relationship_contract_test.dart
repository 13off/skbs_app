import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('company membership embeds the direct company foreign key', () {
    final source = File(
      'lib/features/company/data/company_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('companies!company_memberships_company_id_fkey('),
    );
    expect(source, isNot(contains('companies!inner(')));
  });
}
