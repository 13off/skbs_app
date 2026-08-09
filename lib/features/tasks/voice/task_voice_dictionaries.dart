import '../../../models/employee.dart';
import 'task_voice_active_field.dart';

const _commonHints = <String>[
  'дата',
  'дату',
  'когда',
  'оси',
  'ось',
  'по осям',
  'вид работ',
  'работа',
  'задача',
  'исполнитель',
  'исполнители',
  'кто делает',
  'добавь',
  'убери',
  'замени',
  'поменяй',
  'исправь',
  'оставь',
  'очисти',
  'начнем заново',
  'готово',
  'стоп',
];

const _dateHints = <String>[
  'сегодня',
  'завтра',
  'послезавтра',
  'вчера',
  'понедельник',
  'вторник',
  'среда',
  'четверг',
  'пятница',
  'суббота',
  'воскресенье',
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];

const _numberHints = <String>[
  'ноль',
  'один',
  'два',
  'три',
  'четыре',
  'пять',
  'шесть',
  'семь',
  'восемь',
  'девять',
  'десять',
  'одиннадцать',
  'двенадцать',
  'тринадцать',
  'четырнадцать',
  'пятнадцать',
  'шестнадцать',
  'семнадцать',
  'восемнадцать',
  'девятнадцать',
  'двадцать',
];

const _axisHints = <String>[
  ..._numberHints,
  'а',
  'эй',
  'бэ',
  'бе',
  'би',
  'вэ',
  'ве',
  'ви',
  'гэ',
  'ге',
  'ги',
  'дэ',
  'де',
  'ди',
  'е',
  'жэ',
  'же',
  'и',
  'ка',
  'эль',
  'эл',
  'эм',
  'эн',
  'пэ',
  'пе',
  'эр',
  'эс',
  'тэ',
  'те',
  'бэгэ',
  'беге',
  'беги',
  'вэгэ',
  'веге',
  'бэдэ',
  'беде',
  'борис',
  'виктор',
  'григорий',
  'дмитрий',
  'елена',
  'женя',
  'иван',
  'константин',
  'леонид',
  'михаил',
  'николай',
  'павел',
  'роман',
  'сергей',
  'татьяна',
  'по',
  'до',
  'от',
  'между',
  'тире',
  'дефис',
];

const _workHints = <String>[
  'армирование',
  'доармирование',
  'вязка арматуры',
  'арматура',
  'каркас',
  'сетка',
  'хомуты',
  'выпуски',
  'анкеровка',
  'закладные',
  'опалубка',
  'монтаж опалубки',
  'демонтаж опалубки',
  'распалубка',
  'щитовая опалубка',
  'бетонирование',
  'укладка бетона',
  'прием бетона',
  'вибрирование',
  'вибрация бетона',
  'заливка',
  'подливка',
  'колонна',
  'колонны',
  'стена',
  'стены',
  'перекрытие',
  'плита',
  'плита перекрытия',
  'фундамент',
  'ростверк',
  'ригель',
  'балка',
  'лестница',
  'лестничный марш',
  'диафрагма',
  'ядро жесткости',
  'приямок',
  'парапет',
  'захватка',
  'секция',
  'этаж',
  'уровень',
  'отметка',
  'монтаж',
  'демонтаж',
  'сверление',
  'бурение',
  'штробление',
  'герметизация',
  'гидроизоляция',
  'утепление',
  'кладка',
  'газоблок',
  'кирпичная кладка',
  'стяжка',
  'штукатурка',
  'уборка',
  'подготовка',
  'завершить армирование',
  'завершить опалубку',
  'забетонировать',
];

/// Возвращает небольшой словарь именно для текущего голосового поля.
/// Web Speech получает максимум 160 подсказок, поэтому узкий словарь
/// работает стабильнее одного огромного списка из всех терминов приложения.
List<String> buildTaskVoiceContextHints({
  required TaskVoiceField? activeField,
  required List<Employee> employees,
}) {
  final hints = <String>[..._commonHints];

  switch (activeField) {
    case TaskVoiceField.date:
      hints.addAll(_dateHints);
      hints.addAll(_numberHints);
    case TaskVoiceField.axes:
      hints.addAll(_axisHints);
    case TaskVoiceField.work:
      hints.addAll(_workHints);
    case TaskVoiceField.assignees:
      hints.addAll(_employeeHints(employees));
    case null:
      // До выбора поля нужны только маркеры и самые характерные слова,
      // чтобы первая фраза «оси», «вид работ», «исполнитель» распознавалась
      // без конкуренции сотен нерелевантных терминов.
      hints.addAll(const <String>[
        'армирование',
        'опалубка',
        'бетонирование',
        'сегодня',
        'завтра',
        'бэ',
        'вэ',
        'гэ',
        'дэ',
      ]);
  }

  return normalizeTaskVoiceRecognitionHints(hints).take(150).toList(growable: false);
}

List<String> _employeeHints(List<Employee> employees) {
  final hints = <String>[];
  for (final employee in employees) {
    final name = employee.name.trim();
    if (name.isEmpty) continue;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.isNotEmpty && parts.first.length >= 3) hints.add(parts.first);
    if (parts.length > 1 && parts[1].length >= 3) hints.add(parts[1]);
    hints.add(name);
  }
  return hints;
}

List<String> normalizeTaskVoiceRecognitionHints(Iterable<String> hints) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in hints) {
    final hint = _normalizeRecognitionText(raw);
    if (hint.length < 2 || !seen.add(hint)) continue;
    result.add(hint);
  }
  return result;
}

/// Дополнительный скоринг альтернатив Web Speech.
/// Короткие подсказки (`бе`, `ве`, `ге`) совпадают только с целым словом:
/// `бе` больше не повышает вес слова `бетонирование`.
double scoreTaskVoiceRecognitionHints(
  String transcript,
  List<String> hints,
) {
  if (hints.isEmpty) return 0;
  final normalized = _normalizeRecognitionText(transcript);
  if (normalized.isEmpty) return 0;
  final tokens = normalized.split(' ').toSet();
  var score = 0.0;

  for (final rawHint in hints) {
    final hint = _normalizeRecognitionText(rawHint);
    if (hint.isEmpty) continue;
    if (hint.contains(' ')) {
      final phrase = RegExp('(?:^| )${RegExp.escape(hint)}(?: |\$)');
      if (phrase.hasMatch(normalized)) score += 0.30;
      continue;
    }
    if (tokens.contains(hint)) {
      score += hint.length <= 3 ? 0.32 : 0.22;
    }
  }

  return score > 0.8 ? 0.8 : score;
}

String _normalizeRecognitionText(String value) => value
    .toLowerCase()
    .replaceAll('ё', 'е')
    .replaceAll(RegExp(r'[^а-яa-z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
