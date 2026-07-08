import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:universal_html/html.dart' as html;

import '../models/task_item_data.dart';

class ActGenerator {
  static const String templatePath = 'assets/templates/act_template.docx';

  static Future<List<_TemplateFile>>? _templateFilesFuture;

  static Future<void> downloadAct({
    required List<TaskItemData> tasks,
    required DateTime date,
  }) async {
    final completedTasks = tasks
        .where((task) {
          return task.status == 'Выполнено';
        })
        .toList(growable: false);

    if (completedTasks.isEmpty) {
      throw Exception('Нет выполненных задач для акта');
    }

    final bytes = await createDocxFromTemplate(
      tasks: completedTasks,
      date: date,
    );

    _downloadBytes(bytes: bytes, fileName: _actFileName(date));
  }

  static Future<Uint8List> createDocxFromTemplate({
    required List<TaskItemData> tasks,
    required DateTime date,
  }) async {
    final templateFiles = await _loadTemplateFiles();
    final outputArchive = Archive();

    for (final templateFile in templateFiles) {
      final fileName = templateFile.name;
      final originalBytes = templateFile.bytes;

      if (fileName == 'word/document.xml') {
        final xml = utf8.decode(originalBytes);
        final newXml = _fillDocumentXml(xml: xml, tasks: tasks, date: date);
        final newBytes = utf8.encode(newXml);

        outputArchive.addFile(ArchiveFile(fileName, newBytes.length, newBytes));
      } else {
        outputArchive.addFile(
          ArchiveFile(fileName, originalBytes.length, originalBytes),
        );
      }
    }

    final zipped = ZipEncoder().encode(outputArchive);

    if (zipped == null) {
      throw Exception('Не удалось собрать DOCX');
    }

    return Uint8List.fromList(zipped);
  }

  static Future<List<_TemplateFile>> _loadTemplateFiles() {
    _templateFilesFuture ??= _readTemplateFilesFromAssets();
    return _templateFilesFuture!;
  }

  static Future<List<_TemplateFile>> _readTemplateFilesFromAssets() async {
    final templateData = await rootBundle.load(templatePath);
    final templateBytes = Uint8List.fromList(
      templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      ),
    );

    final inputArchive = ZipDecoder().decodeBytes(templateBytes);
    final files = <_TemplateFile>[];

    for (final file in inputArchive.files) {
      if (!file.isFile) continue;

      files.add(
        _TemplateFile(name: file.name, bytes: _bytesFromArchiveFile(file)),
      );
    }

    if (files.isEmpty) {
      throw Exception('Шаблон акта пустой или повреждён');
    }

    return List<_TemplateFile>.unmodifiable(files);
  }

  static String _fillDocumentXml({
    required String xml,
    required List<TaskItemData> tasks,
    required DateTime date,
  }) {
    var result = xml;

    final dateValue = _dateText(date);
    final worksXml = _buildWorksXml(tasks);

    // В шаблоне date и tasks могут быть элементами управления Word:
    // <w:sdt> с alias="date" и alias="tasks".
    // Сначала меняем их. Если alias найден, тяжёлый запасной поиск по абзацам не гоняем.
    final beforeDateAlias = result;
    result = _replaceContentControlByAlias(
      xml: result,
      alias: 'date',
      replacementXml: _run(dateValue),
    );
    final dateAliasWasUsed = result != beforeDateAlias;

    final beforeTasksAlias = result;
    result = _replaceContentControlByAlias(
      xml: result,
      alias: 'tasks',
      replacementXml: worksXml,
    );
    final tasksAliasWasUsed = result != beforeTasksAlias;

    // Запасной вариант, если в шаблоне будут не элементы Word,
    // а обычный текст date/tasks.
    if (!dateAliasWasUsed) {
      result = _replacePlainDateInTextNodes(xml: result, dateValue: dateValue);
    }

    if (!tasksAliasWasUsed) {
      result = _replacePlainTasksParagraph(xml: result, worksXml: worksXml);
    }

    return result;
  }

  static String _replaceContentControlByAlias({
    required String xml,
    required String alias,
    required String replacementXml,
  }) {
    final regex = RegExp(
      '<w:sdt\\b[\\s\\S]*?<w:alias[^>]*w:val="${RegExp.escape(alias)}"[^>]*/>[\\s\\S]*?</w:sdt>',
      multiLine: true,
    );

    return xml.replaceAll(regex, replacementXml);
  }

  static String _replacePlainDateInTextNodes({
    required String xml,
    required String dateValue,
  }) {
    final textRegex = RegExp('<w:t([^>]*)>([\\s\\S]*?)</w:t>', multiLine: true);

    return xml.replaceAllMapped(textRegex, (match) {
      final attrs = match.group(1) ?? '';
      final rawText = match.group(2) ?? '';
      final visibleText = _unescapeXml(rawText);

      final replacedText = visibleText
          .replaceAll('{{date}}', dateValue)
          .replaceAll('{{DATE}}', dateValue)
          .replaceAll('[date]', dateValue)
          .replaceAll('[DATE]', dateValue)
          .replaceAll('date', dateValue);

      if (replacedText == visibleText) {
        return match.group(0) ?? '';
      }

      return '<w:t$attrs>${_escapeXml(replacedText)}</w:t>';
    });
  }

  static String _replacePlainTasksParagraph({
    required String xml,
    required String worksXml,
  }) {
    final paragraphRegex = RegExp('<w:p[\\s\\S]*?</w:p>', multiLine: true);

    return xml.replaceAllMapped(paragraphRegex, (match) {
      final paragraphXml = match.group(0) ?? '';
      final visibleText = _visibleTextFromParagraph(paragraphXml).trim();

      final isPlaceholder =
          visibleText == 'tasks' ||
          visibleText == 'TASKS' ||
          visibleText == '{{tasks}}' ||
          visibleText == '{{TASKS}}' ||
          visibleText == '[tasks]' ||
          visibleText == '[TASKS]';

      if (!isPlaceholder) {
        return paragraphXml;
      }

      return worksXml;
    });
  }

  static String _visibleTextFromParagraph(String paragraphXml) {
    final textRegex = RegExp('<w:t[^>]*>([\\s\\S]*?)</w:t>', multiLine: true);

    final parts = textRegex.allMatches(paragraphXml).map((match) {
      final text = match.group(1) ?? '';

      return _unescapeXml(text);
    });

    return parts.join();
  }

  static String _buildWorksXml(List<TaskItemData> tasks) {
    final groupedWorks = _groupWorksByAxes(tasks);
    final buffer = StringBuffer();

    groupedWorks.forEach((axes, works) {
      if (axes.isNotEmpty) {
        buffer.write(_workParagraph('В осях $axes'));
      }

      for (final work in works) {
        buffer.write(_workParagraph(_productionSentence(work)));
      }

      buffer.write(_emptyWorkParagraph());
    });

    return buffer.toString();
  }

  static Map<String, List<String>> _groupWorksByAxes(List<TaskItemData> tasks) {
    final grouped = <String, List<String>>{};

    for (final task in tasks) {
      final axes = task.axes.trim();
      final workLines = _splitWorkLines(task.work);

      if (workLines.isEmpty) continue;

      grouped.putIfAbsent(axes, () => <String>[]).addAll(workLines);
    }

    return grouped;
  }

  static List<String> _splitWorkLines(String value) {
    return value
        .split(RegExp(r'\r?\n'))
        .map(_cleanWorkText)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  static String _cleanWorkText(String value) {
    var text = value.trim();

    final prefixes = [
      'Выполнены работы:',
      'Выполнены работы',
      'Выполнена работа:',
      'Выполнена работа',
      'Выполнено:',
      'Выполнено',
    ];

    for (final prefix in prefixes) {
      if (text.toLowerCase().startsWith(prefix.toLowerCase())) {
        text = text.substring(prefix.length).trim();
        break;
      }
    }

    return text;
  }

  static String _productionSentence(String value) {
    final originalText = value.trim();

    if (originalText.isEmpty) {
      return '';
    }

    final lowerText = originalText.toLowerCase();

    if (lowerText.startsWith('производил') ||
        lowerText.startsWith('производилась') ||
        lowerText.startsWith('производилось') ||
        lowerText.startsWith('производились') ||
        lowerText.startsWith('производился')) {
      return _normalizeWorkText(originalText);
    }

    final firstWord = _firstWord(lowerText);
    final verb = _productionVerbFor(firstWord);
    final preparedText = _lowerFirstLetter(originalText);

    return _normalizeWorkText('$verb $preparedText');
  }

  static String _productionVerbFor(String firstWord) {
    if (firstWord.isEmpty) {
      return 'Производилось';
    }

    final pluralWords = [
      'работы',
      'мероприятия',
      'операции',
      'испытания',
      'замеры',
      'перестановки',
      'переносы',
    ];

    final masculineWords = [
      'монтаж',
      'демонтаж',
      'ремонт',
      'вынос',
      'перенос',
      'прогрев',
      'обогрев',
      'спуск',
      'подъем',
      'подъём',
      'запуск',
      'осмотр',
      'контроль',
    ];

    final feminineWords = [
      'уборка',
      'шлифовка',
      'заливка',
      'установка',
      'вязка',
      'разборка',
      'подготовка',
      'очистка',
      'разметка',
      'проверка',
      'резка',
      'подача',
      'сборка',
    ];

    final neuterWords = [
      'армирование',
      'бетонирование',
      'крепление',
      'устройство',
      'восстановление',
      'усиление',
      'выравнивание',
      'скрепление',
      'бурение',
      'сверление',
      'перемещение',
      'складирование',
    ];

    if (pluralWords.contains(firstWord) ||
        firstWord.endsWith('ы') ||
        firstWord.endsWith('и')) {
      return 'Производились';
    }

    if (masculineWords.contains(firstWord)) {
      return 'Производился';
    }

    if (feminineWords.contains(firstWord) ||
        firstWord.endsWith('ка') ||
        firstWord.endsWith('га') ||
        firstWord.endsWith('ция') ||
        firstWord.endsWith('а') ||
        firstWord.endsWith('я')) {
      return 'Производилась';
    }

    if (neuterWords.contains(firstWord) ||
        firstWord.endsWith('ние') ||
        firstWord.endsWith('тие') ||
        firstWord.endsWith('ство') ||
        firstWord.endsWith('ие') ||
        firstWord.endsWith('е') ||
        firstWord.endsWith('о')) {
      return 'Производилось';
    }

    return 'Производился';
  }

  static String _firstWord(String text) {
    final match = RegExp(r'^[а-яА-ЯёЁa-zA-Z0-9-]+').firstMatch(text.trim());

    return match?.group(0)?.toLowerCase() ?? '';
  }

  static String _lowerFirstLetter(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return '';
    }

    if (text.length == 1) {
      return text.toLowerCase();
    }

    return text[0].toLowerCase() + text.substring(1);
  }

  static String _workParagraph(String text) {
    final safeText = _escapeXml(text);

    return '''
<w:p>
  <w:pPr>
    <w:spacing w:after="240" w:line="264" w:lineRule="auto"/>
    <w:ind w:right="130"/>
  </w:pPr>
  <w:r>
    <w:t xml:space="preserve">$safeText</w:t>
  </w:r>
</w:p>
''';
  }

  static String _emptyWorkParagraph() {
    return '''
<w:p>
  <w:pPr>
    <w:spacing w:after="240" w:line="264" w:lineRule="auto"/>
    <w:ind w:right="130"/>
  </w:pPr>
</w:p>
''';
  }

  static String _run(String text) {
    return '''
<w:r>
  <w:t xml:space="preserve">${_escapeXml(text)}</w:t>
</w:r>
''';
  }

  static String _normalizeWorkText(String value) {
    final text = value.trim();

    if (text.isEmpty) {
      return '';
    }

    final last = text[text.length - 1];
    const punctuation = ['.', '!', '?'];

    if (punctuation.contains(last)) {
      return text;
    }

    return '$text.';
  }

  static Uint8List _bytesFromArchiveFile(ArchiveFile file) {
    final content = file.content;

    if (content is Uint8List) {
      return Uint8List.fromList(content);
    }

    if (content is List<int>) {
      return Uint8List.fromList(content);
    }

    throw Exception('Не удалось прочитать файл из шаблона: ${file.name}');
  }

  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _unescapeXml(String value) {
    return value
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&gt;', '>')
        .replaceAll('&lt;', '<')
        .replaceAll('&amp;', '&');
  }

  static String _dateText(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    final month = months[date.month - 1];
    final year = date.year.toString();

    return '« $day » $month $year г.';
  }

  static String _actFileName(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return 'Акт о выполненных работах $day.$month.docx';
  }

  static void _downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    html.Url.revokeObjectUrl(url);
  }
}

class _TemplateFile {
  final String name;
  final Uint8List bytes;

  const _TemplateFile({required this.name, required this.bytes});
}
