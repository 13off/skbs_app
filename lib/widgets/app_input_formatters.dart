import 'package:flutter/services.dart';

abstract final class AppInputFormatters {
  static const List<TextInputFormatter> sentences = <TextInputFormatter>[
    AppLeadingCapitalFormatter(),
  ];
  static const List<TextInputFormatter> groupedNumber = <TextInputFormatter>[
    AppGroupedNumberFormatter(),
  ];
  static const List<TextInputFormatter> russianPhone = <TextInputFormatter>[
    AppRussianPhoneFormatter(),
  ];

  static String normalizeNumber(String value) {
    return value
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '')
        .replaceAll('\u202f', '')
        .replaceAll(',', '.')
        .trim();
  }

  static double? tryParseDouble(String value) {
    return double.tryParse(normalizeNumber(value));
  }

  static int? tryParseInt(String value) {
    final normalized = normalizeNumber(value);
    return int.tryParse(normalized) ?? double.tryParse(normalized)?.round();
  }

  static String formatNumber(String value) {
    return const AppGroupedNumberFormatter().format(value);
  }

  static String formatRussianPhone(String value) {
    return const AppRussianPhoneFormatter().format(value);
  }
}

class AppLeadingCapitalFormatter extends TextInputFormatter {
  const AppLeadingCapitalFormatter();

  static final RegExp _letter = RegExp(r'[A-Za-zА-Яа-яЁё]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final match = _letter.firstMatch(newValue.text);
    if (match == null) return newValue;

    final index = match.start;
    final source = newValue.text;
    final formatted = source.replaceRange(
      index,
      index + 1,
      source.substring(index, index + 1).toUpperCase(),
    );
    return newValue.copyWith(text: formatted);
  }
}

class AppGroupedNumberFormatter extends TextInputFormatter {
  const AppGroupedNumberFormatter();

  String _format(
    String value, {
    required String outputSeparator,
  }) {
    var source = value
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '')
        .replaceAll('\u202f', '');
    final negative = source.startsWith('-');
    if (negative) source = source.substring(1);

    final dotIndex = source.lastIndexOf('.');
    final commaIndex = source.lastIndexOf(',');
    final separatorIndex = dotIndex > commaIndex ? dotIndex : commaIndex;
    final hasSeparator = separatorIndex >= 0;

    var integerPart = (hasSeparator
            ? source.substring(0, separatorIndex)
            : source)
        .replaceAll(RegExp(r'\D'), '');
    final fractionPart = hasSeparator
        ? source.substring(separatorIndex + 1).replaceAll(RegExp(r'\D'), '')
        : '';

    if (integerPart.isEmpty && hasSeparator) integerPart = '0';
    if (integerPart.isEmpty) return '';

    final groups = <String>[];
    for (var end = integerPart.length; end > 0; end -= 3) {
      final start = end - 3 < 0 ? 0 : end - 3;
      groups.add(integerPart.substring(start, end));
    }
    final groupedInteger = groups.reversed.join(' ');
    return '${negative ? '-' : ''}$groupedInteger'
        '${hasSeparator ? '$outputSeparator$fractionPart' : ''}';
  }

  String format(String value) {
    // Programmatic formatting stays in the existing Russian presentation
    // format, while interactive editing preserves the separator the user
    // actually typed.
    return _format(value, outputSeparator: ',');
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final source = newValue.text;
    final dotIndex = source.lastIndexOf('.');
    final commaIndex = source.lastIndexOf(',');
    final separator = dotIndex > commaIndex ? '.' : ',';
    final formatted = _format(source, outputSeparator: separator);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}

class AppRussianPhoneFormatter extends TextInputFormatter {
  const AppRussianPhoneFormatter();

  String format(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
    if (!digits.startsWith('7')) digits = '7$digits';
    if (digits.length > 11) digits = digits.substring(0, 11);

    final local = digits.substring(1);
    final buffer = StringBuffer('+7');
    if (local.isNotEmpty) {
      final end = local.length < 3 ? local.length : 3;
      buffer.write(' (${local.substring(0, end)}');
      if (local.length >= 3) buffer.write(')');
    }
    if (local.length > 3) {
      final end = local.length < 6 ? local.length : 6;
      buffer.write(' ${local.substring(3, end)}');
    }
    if (local.length > 6) {
      final end = local.length < 8 ? local.length : 8;
      buffer.write('-${local.substring(6, end)}');
    }
    if (local.length > 8) {
      final end = local.length < 10 ? local.length : 10;
      buffer.write('-${local.substring(8, end)}');
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}
