import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/widgets/app_input_formatters.dart';

TextEditingValue edit(TextInputFormatter formatter, String value) {
  return formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
  );
}

void main() {
  test('numbers are grouped by thousands and keep decimal comma', () {
    const formatter = AppGroupedNumberFormatter();

    expect(edit(formatter, '3500').text, '3 500');
    expect(edit(formatter, '1250000').text, '1 250 000');
    expect(edit(formatter, '1234.56').text, '1 234,56');
    expect(AppInputFormatters.tryParseDouble('1 234,56'), 1234.56);
  });

  test('phone is entered in one Russian format', () {
    const formatter = AppRussianPhoneFormatter();

    expect(edit(formatter, '89991234567').text, '+7 (999) 123-45-67');
    expect(edit(formatter, '+7 999 123 45 67').text, '+7 (999) 123-45-67');
  });

  test('ordinary text starts with a capital letter', () {
    const formatter = AppLeadingCapitalFormatter();

    expect(edit(formatter, '  проверка').text, '  Проверка');
    expect(edit(formatter, 'Мурманск').text, 'Мурманск');
  });
}
