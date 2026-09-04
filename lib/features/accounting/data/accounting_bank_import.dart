import 'dart:convert';
import 'dart:typed_data';

import 'accounting_workbench_repository.dart';

class AccountingBankImportResult {
  final List<AccountingBankImportRow> rows;
  final List<String> warnings;

  const AccountingBankImportResult({
    required this.rows,
    required this.warnings,
  });
}

class AccountingBankImport {
  static AccountingBankImportResult parse(Uint8List bytes) {
    final text = _decode(bytes).replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2) {
      throw const FormatException('В выписке нет строк для импорта');
    }

    final delimiter = _detectDelimiter(lines.first);
    final headers = _splitLine(lines.first, delimiter)
        .map(_normalizeHeader)
        .toList(growable: false);

    final dateIndex = _find(headers, const [
      'дата',
      'дата операции',
      'operation date',
      'date',
    ]);
    final incomingIndex = _find(headers, const [
      'приход',
      'поступление',
      'поступления',
      'кредит',
      'credit',
      'income',
    ]);
    final outgoingIndex = _find(headers, const [
      'расход',
      'списание',
      'списания',
      'дебет',
      'debit',
      'outcome',
      'expense',
    ]);
    final amountIndex = _find(headers, const ['сумма', 'amount']);
    final directionIndex = _find(headers, const [
      'тип',
      'тип операции',
      'направление',
      'direction',
    ]);
    final counterpartyIndex = _find(headers, const [
      'контрагент',
      'корреспондент',
      'получатель',
      'плательщик',
      'наименование контрагента',
      'counterparty',
    ]);
    final purposeIndex = _find(headers, const [
      'назначение',
      'назначение платежа',
      'описание',
      'purpose',
      'description',
    ]);
    final referenceIndex = _find(headers, const [
      'номер документа',
      'номер',
      'document number',
      'reference',
    ]);

    if (dateIndex < 0) {
      throw const FormatException('Не найдена колонка с датой операции');
    }
    if (incomingIndex < 0 && outgoingIndex < 0 && amountIndex < 0) {
      throw const FormatException('Не найдены колонки с суммой операции');
    }

    final rows = <AccountingBankImportRow>[];
    final warnings = <String>[];

    for (var i = 1; i < lines.length; i++) {
      final cells = _splitLine(lines[i], delimiter);
      String cell(int index) => index >= 0 && index < cells.length
          ? cells[index].trim()
          : '';

      final date = _parseDate(cell(dateIndex));
      if (date == null) {
        warnings.add('Строка ${i + 1}: не распознана дата');
        continue;
      }

      final incoming = _parseMoney(cell(incomingIndex));
      final outgoing = _parseMoney(cell(outgoingIndex));
      final genericAmount = _parseMoney(cell(amountIndex));
      String direction;
      double amount;

      if (incoming > 0) {
        direction = 'in';
        amount = incoming;
      } else if (outgoing > 0) {
        direction = 'out';
        amount = outgoing;
      } else if (genericAmount != 0) {
        final directionText = cell(directionIndex).toLowerCase();
        if (directionText.contains('приход') ||
            directionText.contains('поступ') ||
            directionText.contains('credit') ||
            directionText.contains('income')) {
          direction = 'in';
        } else if (directionText.contains('расход') ||
            directionText.contains('спис') ||
            directionText.contains('debit') ||
            directionText.contains('expense')) {
          direction = 'out';
        } else {
          direction = genericAmount < 0 ? 'out' : 'in';
        }
        amount = genericAmount.abs();
      } else {
        warnings.add('Строка ${i + 1}: сумма равна нулю или не распознана');
        continue;
      }

      rows.add(
        AccountingBankImportRow(
          date: date,
          direction: direction,
          amount: amount,
          counterparty: cell(counterpartyIndex),
          purpose: cell(purposeIndex),
          bankReference: cell(referenceIndex),
        ),
      );
    }

    if (rows.isEmpty) {
      throw const FormatException('Не удалось распознать ни одной операции');
    }
    return AccountingBankImportResult(rows: rows, warnings: warnings);
  }

  static String _decode(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      // Большинство современных банков отдают UTF-8. Для старых кодировок
      // пользователь увидит понятную ошибку вместо повреждённых данных.
      throw const FormatException(
        'Файл не в UTF-8. Сохраните банковскую выписку как CSV UTF-8.',
      );
    }
  }

  static String _detectDelimiter(String header) {
    final candidates = <String, int>{
      ';': ';'.allMatches(header).length,
      '\t': '\t'.allMatches(header).length,
      ',': ','.allMatches(header).length,
    };
    return candidates.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static List<String> _splitLine(String line, String delimiter) {
    final result = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          current.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  static String _normalizeHeader(String value) {
    return value
        .replaceAll('\ufeff', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _find(List<String> headers, List<String> names) {
    for (final name in names) {
      final exact = headers.indexOf(name);
      if (exact >= 0) return exact;
    }
    for (var i = 0; i < headers.length; i++) {
      for (final name in names) {
        if (headers[i].contains(name)) return i;
      }
    }
    return -1;
  }

  static DateTime? _parseDate(String value) {
    final clean = value.trim().split(' ').first;
    final iso = DateTime.tryParse(clean);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final parts = clean.split(RegExp(r'[./-]'));
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    final c = int.tryParse(parts[2]);
    if (a == null || b == null || c == null) return null;
    try {
      if (parts[0].length == 4) return DateTime(a, b, c);
      final year = c < 100 ? 2000 + c : c;
      return DateTime(year, b, a);
    } catch (_) {
      return null;
    }
  }

  static double _parseMoney(String value) {
    if (value.trim().isEmpty) return 0;
    var clean = value
        .replaceAll('\u00a0', '')
        .replaceAll(' ', '')
        .replaceAll('₽', '')
        .replaceAll('руб.', '')
        .replaceAll('руб', '')
        .trim();
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean) ?? 0;
  }
}
