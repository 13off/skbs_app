import '../../models/app_user_profile.dart';

const _commonHints = <String>[
  'AppСтрой',
  'открой',
  'покажи',
  'найди',
  'проверь',
  'сводка',
  'отчет',
  'сегодня',
  'завтра',
  'вчера',
  'за неделю',
  'за месяц',
  'объект',
  'объекты',
  'сотрудник',
  'сотрудники',
  'задача',
  'задачи',
  'табель',
  'смена',
  'смены',
  'выплата',
  'выплаты',
  'документ',
  'документы',
  'уведомления',
  'настройки',
  'чат',
  'сообщение',
  'напоминание',
  'создай',
  'добавь',
  'измени',
  'исправь',
  'подготовь',
  'сформируй',
  'назначь',
];

const _managerHints = <String>[
  'руководитель',
  'дашборд',
  'начисления',
  'баланс',
  'долг',
  'задолженность',
  'чек',
  'чеки',
  'акт выполненных работ',
  'веха',
  'вехи',
  'цель',
  'чеклист',
  'прогресс',
  'исполнение задач',
  'маршруты',
  'недельный вклад',
  'кадры',
  'юристы',
  'снабжение',
  'бухгалтерия',
  'архив',
  'пользователи',
  'компания',
  'тариф',
];

const _foremanHints = <String>[
  'прораб',
  'оси',
  'вид работ',
  'исполнитель',
  'исполнители',
  'армирование',
  'арматура',
  'опалубка',
  'бетонирование',
  'бетон',
  'монтаж',
  'демонтаж',
  'распалубка',
  'колонна',
  'стена',
  'перекрытие',
  'плита',
  'фундамент',
  'ростверк',
  'ригель',
  'захватка',
  'доармирование',
  'акт работ',
  'выполнено',
  'в работе',
  'прогресс задачи',
];

const _accountingHints = <String>[
  'бухгалтерия',
  'бухгалтер',
  'выплата',
  'аванс',
  'зарплата',
  'штраф',
  'сумма',
  'расчетный месяц',
  'дата выплаты',
  'начислено',
  'выплачено',
  'остаток',
  'баланс',
  'реестр выплат',
  'чек',
  'чек отсутствует',
  'без чека',
  'подтвержденный чек',
  'месячный табель',
  'операционный аудит',
  'переплата',
  'дубликат выплаты',
  'сверка табеля',
];

const _hrHints = <String>[
  'HR',
  'кадры',
  'кандидат',
  'кандидаты',
  'соискатель',
  'заявка кандидата',
  'вакансия',
  'ответственный',
  'этап',
  'этап кандидата',
  'собеседование',
  'одобрен',
  'приехал',
  'принят',
  'архив кандидатов',
  'назначить ответственного',
  'массовый перевод',
  'оформление',
  'онбординг',
  'согласие на персональные данные',
  'пакет документов',
  'комплект документов',
  'распечатано',
  'подписанный документ',
  'рейс',
  'авиарейс',
  'билет',
  'вылет',
  'прилет',
  'напомнить о рейсе',
];

const _legalHints = <String>[
  'юрист',
  'юридический',
  'договор',
  'договоры',
  'соглашение',
  'акт',
  'доверенность',
  'кадровый документ',
  'контрагент',
  'претензия',
  'нарушение',
  'спор',
  'юридическая задача',
  'риск',
  'высокий риск',
  'срок',
  'ответственный',
  'обязательные действия',
  'решение руководителя',
  'одобрить',
  'отклонить',
  'комментарий решения',
];

const _procurementHints = <String>[
  'снабжение',
  'снабженец',
  'закупка',
  'заявка на снабжение',
  'заявка',
  'поставщик',
  'поставщики',
  'доставка',
  'поставка',
  'позиция',
  'позиции',
  'материал',
  'материалы',
  'сумма',
  'приоритет',
  'заказано',
  'в доставке',
  'доставлено',
  'закрыто',
  'отменить заявку',
  'ИНН поставщика',
  'контакт поставщика',
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
}) {
  final hints = <String>[..._commonHints];

  if (profile.isAdmin) {
    hints
      ..addAll(_managerHints)
      ..addAll(_foremanHints)
      ..addAll(_accountingHints)
      ..addAll(_hrHints)
      ..addAll(_legalHints)
      ..addAll(_procurementHints);
  } else if (profile.isForeman) {
    hints.addAll(_foremanHints);
  } else if (profile.isAccountant) {
    hints.addAll(_accountingHints);
  } else if (profile.isHr) {
    hints.addAll(_hrHints);
  } else if (profile.isLawyer) {
    hints.addAll(_legalHints);
  } else if (profile.isProcurement) {
    hints.addAll(_procurementHints);
  } else if (profile.isEmployee) {
    hints.addAll(_employeeHints);
  }

  if (profile.isDeveloper) hints.addAll(_developerHints);

  hints.addAll(objectNames);
  for (final rawName in employeeNames) {
    final name = rawName.trim();
    if (name.isEmpty) continue;
    hints.add(name);
    final parts = name.split(RegExp(r'\s+'));
    for (final part in parts.take(2)) {
      if (part.length >= 3) hints.add(part);
    }
  }

  final ownObject = profile.objectName.trim();
  if (ownObject.isNotEmpty) hints.add(ownObject);

  return _normalizeHints(hints).take(220).toList(growable: false);
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
