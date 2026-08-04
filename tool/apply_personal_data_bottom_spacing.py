from pathlib import Path

screen = Path('lib/screens/employee_private_data_screen.dart')
text = screen.read_text()

import_marker = "import 'package:flutter/services.dart';\n\n"
import_value = "import 'package:flutter/services.dart';\n\nimport '../app/app_ui_tokens.dart';\n"
if text.count(import_marker) != 1:
    raise SystemExit('Unexpected imports in employee private data screen')
text = text.replace(import_marker, import_value, 1)

build_marker = """  Widget build(BuildContext context) {
    final digitKeyboard = TextInputType.number;

    if (isLoading) {
"""
build_value = """  Widget build(BuildContext context) {
    final digitKeyboard = TextInputType.number;
    final bottomSpacing = AppUi.navigationTotalHeight(context) + 24;

    if (isLoading) {
"""
if text.count(build_marker) != 1:
    raise SystemExit('Unexpected build method in employee private data screen')
text = text.replace(build_marker, build_value, 1)

padding_marker = "        padding: const EdgeInsets.all(18),"
padding_value = (
    "        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomSpacing),"
)
if text.count(padding_marker) != 1:
    raise SystemExit('Unexpected personal data list padding')
text = text.replace(padding_marker, padding_value, 1)
screen.write_text(text)

Path('test/employee_private_data_bottom_spacing_contract_test.dart').write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal data save action scrolls above floating navigation', () {
    final source = File(
      'lib/screens/employee_private_data_screen.dart',
    ).readAsStringSync();

    expect(source, contains("import '../app/app_ui_tokens.dart';"));
    expect(
      source,
      contains('AppUi.navigationTotalHeight(context) + 24'),
    );
    expect(
      source,
      contains('EdgeInsets.fromLTRB(18, 18, 18, bottomSpacing)'),
    );
    expect(source, contains("'Сохранить личные данные'"));
    expect(source, isNot(contains('padding: const EdgeInsets.all(18)')));
  });
}
"""
)
