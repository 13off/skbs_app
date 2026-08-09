import '../../models/app_user_profile.dart';

/// Web Speech в текущем голосовом движке использует первые 160 JSGF-подсказок.
/// Поэтому здесь важен не размер словаря, а порядок: сначала живые сущности,
/// затем самые полезные команды и только потом широкий профессиональный словарь.
const _browserGrammarBudget = 160;
const _objectHintBudget = 18;
const _employeeHintBudget = 48;
const _domainHintBudget = 30;
const _commonHintBudget = 34;
const _roleHintBudget = 30;

const _commonHints = <String>[
  'AppСтрой',
  'создай',
  'добавь',
  'измени',
  'исправь',
  'назначь',
  'открой',
  'покажи',
  'найди',
  'проверь',
  'сегодня',
  'завтра',
  'вчера',
  'отмена',
  'не надо',
  'стоп',
  'то же самое',
  'повтори',
  'не это',
  'вместо',
  'подтверди',
  'выполняй',
  'потом',
  'после этого',
  'этот сотрудник',
  'эта заявка',
  'этот кандидат',
  'на этом объекте',
  'другой объект',
  'ему',
  'ей',
  'им',
  'их',
  'его',
  'так же',
  'еще раз',
  'подтверждай',
  'затем',
  'второй объект',
  'тот объект',
  'последний',
  'предыдущий',
  'первый',
  'второй',
  'ее',
  'объект',
  'сотрудник',
  'задача',
  'табель',
  'смена',
  'выплата',
  'документы',
  'чат',
  'сообщение',
  'сводка',
  'отчет',
  'уведомления',
  'настройки',
  'напоминание',
  'подготовь',
  'сформируй',
  'за неделю',
  'за месяц',
];

const _managerHints = <String>[
  'руководитель',
  'дашборд',
  'задолженность',
  'акт выполненных работ',
  'цель',
  'прогресс',
  'кадры',
  'снабжение',
  'бухгалтерия',
  'юристы',
  'архив',
  'пользователи',
  'компания',
  'тариф',
  'начисления',
  'баланс',
  'долг',
  'чек',
  'веха',
  'чеклист',
  'исполнение задач',
  'маршруты',
  'недельный вклад',
];

const _foremanHints = <String>[
  'армирование',
  'опалубка',
  'бетонирование',
  'оси',
  'захватка',
  'ростверк',
  'ригель',
  'доармирование',
  'вязка арматуры',
  'армокаркас',
  'каркас',
  'сетка',
  'хомуты',
  'выпуски',
  'анкеровка',
  'закладные',
  'бетон',
  'прием бетона',
  'укладка бетона',
  'вибрирование',
  'заливка',
  'распалубка',
  'монтаж опалубки',
  'демонтаж опалубки',
  'колонна',
  'стена',
  'перекрытие',
  'плита перекрытия',
  'фундамент',
  'балка',
  'диафрагма',
  'ядро жесткости',
  'лестничный марш',
  'приямок',
  'парапет',
  'секция',
  'этаж',
  'уровень',
  'отметка',
  'вид работ',
  'исполнитель',
  'прораб',
  'выполнено',
  'в работе',
  'прогресс задачи',
];

const _accountingHints = <String>[
  'аванс',
  'вознаграждение',
  'реестр выплат',
  'начислено',
  'выплачено',
  'остаток',
  'задолженность',
  'сверка табеля',
  'месячный табель',
  'переплата',
  'дубликат выплаты',
  'чек отсутствует',
  'без чека',
  'подтвержденный чек',
  'расчетный месяц',
  'дата выплаты',
  'штраф',
  'сумма',
  'баланс',
  'операционный аудит',
  'бухгалтерия',
  'бухгалтер',
  'зарплата',
  'выплата',
];

const _hrHints = <String>[
  'кандидат',
  'соискатель',
  'ответственный',
  'этап кандидата',
  'готов к вылету',
  'билеты',
  'вылет',
  'прилет',
  'рейс',
  'паспорт',
  'прописка',
  'СНИЛС',
  'ИНН',
  'полис',
  'ГПХ',
  'персональные данные',
  'анкета',
  'пакет документов',
  'комплект документов',
  'подписанный документ',
  'вакансия',
  'собеседование',
  'онбординг',
  'резерв',
  'отказ',
  'проблемы',
  'архив кандидатов',
  'назначить ответственного',
  'массовый перевод',
  'оформление',
  'авиарейс',
  'билет',
  'напомнить о рейсе',
  'эйчар',
  'кадры',
];

const _legalHints = <String>[
  'договор ГПХ',
  'договор оказания услуг',
  'претензия',
  'юридическая задача',
  'высокий риск',
  'критический риск',
  'решение руководителя',
  'контрагент',
  'доверенность',
  'акт',
  'соглашение',
  'исковое заявление',
  'нарушение',
  'спор',
  'обязательные действия',
  'срок',
  'одобрить',
  'отклонить',
  'комментарий решения',
  'кадровый документ',
  'юрист',
  'юридический',
  'договор',
  'риск',
];

const _procurementHints = <String>[
  'заявка на снабжение',
  'поставщик',
  'закупка',
  'доставка',
  'материал',
  'приоритет',
  'арматура',
  'бетон',
  'опалубка',
  'фанера',
  'доска',
  'брус',
  'вязальная проволока',
  'фиксаторы',
  'крепеж',
  'анкер',
  'дюбель',
  'бур',
  'диск',
  'перфоратор',
  'вибратор',
  'инструмент',
  'перчатки',
  'каска',
  'СИЗ',
  'килограмм',
  'тонна',
  'куб',
  'кубометр',
  'кубический метр',
  'погонный метр',
  'квадратный метр',
  'штука',
  'упаковка',
  'заказано',
  'в доставке',
  'доставлено',
  'отменить заявку',
  'ИНН поставщика',
  'контакт поставщика',
  'снабжение',
  'снабженец',
  'поставка',
  'позиция',
];

const _employeeHints = <String>[
  'мой рабочий день',
  'начать рабочий день',
  'закончить рабочий день',
  'завершить рабочий день',
  'отменить начало работы',
  'геолокация',
  'местоположение',
  'проверить геолокацию',
  'мои задачи',
  'активные задачи',
  'история задач',
  'начать задачу',
  'фото до',
  'фото после',
  'прикрепить фото',
];

const _developerHints = <String>[
  'разработчик',
  'состояние системы',
  'ограничения модулей',
  'матрица ролей',
  'матрица прав',
  'диспетчер ИИ',
  'диагностика',
  'системное состояние',
];

List<String> buildAppVoiceHints({
  required AppUserProfile profile,
  Iterable<String> employeeNames = const <String>[],
  Iterable<String> objectNames = const <String>[],
  Iterable<String> candidateNames = const <String>[],
  Iterable<String> supplierNames = const <String>[],
  Iterable<String> materialNames = const <String>[],
}) {
  final objectHints = _normalizeHints(
    _objectEntityHints(<String>[
      if (profile.objectName.trim().isNotEmpty) profile.objectName,
      ...objectNames,
    ]),
  );
  final employeeHints = _normalizeHints(_personEntityHints(employeeNames));
  final candidateHints = _normalizeHints(_personEntityHints(candidateNames));
  final supplierHints = _normalizeHints(_genericEntityHints(supplierNames));
  final materialHints = _normalizeHints(_genericEntityHints(materialNames));
  final domainHints = _normalizeHints(
    _roundRobin(<List<String>>[candidateHints, supplierHints, materialHints]),
  );
  final commonHints = _normalizeHints(<String>[
    ..._commonHints,
    if (profile.profession.trim().isNotEmpty) profile.profession,
  ]);
  final roleHints = _normalizeHints(_roleHints(profile));

  final result = <String>[];
  final seen = <String>{};

  void addBucket(List<String> values, int budget) {
    var added = 0;
    for (final value in values) {
      if (added >= budget || result.length >= _browserGrammarBudget) break;
      if (!seen.add(value)) continue;
      result.add(value);
      added += 1;
    }
  }

  // Живые сущности важнее общих слов: именно их Web Speech чаще искажает,
  // а после распознавания сервер всё равно проверяет роль и неоднозначность.
  addBucket(objectHints, _objectHintBudget);
  addBucket(employeeHints, _employeeHintBudget);
  addBucket(domainHints, _domainHintBudget);
  addBucket(commonHints, _commonHintBudget);
  addBucket(roleHints, _roleHintBudget);

  // Если какой-либо бакет оказался маленьким, не теряем свободное место.
  for (final bucket in <List<String>>[
    objectHints,
    employeeHints,
    domainHints,
    roleHints,
    commonHints,
  ]) {
    for (final value in bucket) {
      if (result.length >= _browserGrammarBudget) break;
      if (seen.add(value)) result.add(value);
    }
  }

  return result.toList(growable: false);
}

List<String> _roleHints(AppUserProfile profile) {
  if (profile.isAdmin) {
    final groups = <List<String>>[
      _managerHints,
      _foremanHints,
      _accountingHints,
      _hrHints,
      _legalHints,
      _procurementHints,
    ];
    return <String>[
      if (profile.isDeveloper) ..._developerHints,
      ..._roundRobin(groups),
    ];
  }
  if (profile.isForeman) return _foremanHints;
  if (profile.isAccountant) return _accountingHints;
  if (profile.isHr) return _hrHints;
  if (profile.isLawyer) return _legalHints;
  if (profile.isProcurement) return _procurementHints;
  if (profile.isEmployee) return _employeeHints;
  return const <String>[];
}

List<String> _roundRobin(List<List<String>> groups) {
  final result = <String>[];
  var index = 0;
  while (groups.any((group) => index < group.length)) {
    for (final group in groups) {
      if (index < group.length) result.add(group[index]);
    }
    index += 1;
  }
  return result;
}

Iterable<String> _objectEntityHints(Iterable<String> names) sync* {
  for (final rawName in names) {
    final name = rawName.trim();
    if (name.isEmpty) continue;
    yield name;

    final parts = name.split(RegExp(r'\s+'));
    final tail = parts.isEmpty ? name : parts.last;
    if (tail.length >= 3) {
      yield tail;
      yield* _russianCaseForms(tail);
    }
  }
}

Iterable<String> _personEntityHints(Iterable<String> names) sync* {
  // Сначала полное ФИО + фамилия для максимально большого числа людей.
  // Имена и падежные варианты идут вторым кругом и заполняют только
  // оставшийся бюджет, не вытесняя людей из конца списка.
  final prepared = <List<String>>[];
  for (final rawName in names) {
    final name = rawName.trim();
    if (name.isEmpty) continue;
    final parts = name.split(RegExp(r'\s+'));
    prepared.add(parts);
    yield name;
    if (parts.isNotEmpty && parts.first.length >= 3) yield parts.first;
  }

  for (final parts in prepared) {
    if (parts.length > 1 && parts[1].length >= 3) yield parts[1];
    if (parts.isNotEmpty && parts.first.length >= 4) {
      yield* _russianCaseForms(parts.first).take(2);
    }
  }
}

Iterable<String> _genericEntityHints(Iterable<String> values) sync* {
  const ignoredTokens = <String>{'ооо', 'ао', 'пао', 'ип'};
  for (final rawValue in values) {
    final value = rawValue.trim();
    if (value.isEmpty) continue;
    yield value;

    final parts = value.split(RegExp(r'\s+'));
    for (final rawPart in parts) {
      final part = rawPart
          .toLowerCase()
          .replaceAll('ё', 'е')
          .replaceAll(RegExp(r'[^а-яa-z0-9-]'), '');
      if (part.length < 3 || ignoredTokens.contains(part)) continue;
      yield part;
      if (RegExp(r'^[а-я-]+$').hasMatch(part) && part.length >= 4) {
        yield* _russianCaseForms(part).take(2);
      }
    }
  }
}

String _withEnding(String stem, String ending) => '$stem$ending';

Iterable<String> _russianCaseForms(String rawWord) sync* {
  final word = rawWord
      .trim()
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^а-я-]'), '');
  if (word.length < 4) return;

  if (word.endsWith('ий')) {
    final stem = word.substring(0, word.length - 2);
    yield _withEnding(stem, 'ия');
    yield _withEnding(stem, 'ию');
    yield _withEnding(stem, 'ием');
    yield _withEnding(stem, 'ии');
    return;
  }
  if (word.endsWith('ей')) {
    final stem = word.substring(0, word.length - 2);
    yield _withEnding(stem, 'ея');
    yield _withEnding(stem, 'ею');
    yield _withEnding(stem, 'еем');
    yield _withEnding(stem, 'ее');
    return;
  }
  if (word.endsWith('й')) {
    final stem = word.substring(0, word.length - 1);
    yield _withEnding(stem, 'я');
    yield _withEnding(stem, 'ю');
    yield _withEnding(stem, 'ем');
    yield _withEnding(stem, 'е');
    return;
  }
  if (word.endsWith('ь')) {
    final stem = word.substring(0, word.length - 1);
    yield _withEnding(stem, 'я');
    yield _withEnding(stem, 'ю');
    yield _withEnding(stem, 'ем');
    yield _withEnding(stem, 'е');
    return;
  }
  if (word.endsWith('а')) {
    final stem = word.substring(0, word.length - 1);
    yield _withEnding(stem, 'ы');
    yield _withEnding(stem, 'е');
    yield _withEnding(stem, 'у');
    yield _withEnding(stem, 'ой');
    return;
  }
  if (word.endsWith('я')) {
    final stem = word.substring(0, word.length - 1);
    yield _withEnding(stem, 'и');
    yield _withEnding(stem, 'е');
    yield _withEnding(stem, 'ю');
    yield _withEnding(stem, 'ей');
    return;
  }
  if (RegExp(r'[бвгджзклмнпрстфхцчшщ]$').hasMatch(word)) {
    yield _withEnding(word, 'а');
    yield _withEnding(word, 'у');
    yield _withEnding(word, 'ом');
    yield _withEnding(word, 'е');
  }
}

List<String> _normalizeHints(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in values) {
    final value = raw
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (value.length < 2 || !seen.add(value)) continue;
    result.add(value);
  }
  return result;
}
