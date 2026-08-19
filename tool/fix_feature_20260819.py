from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:100]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


ui = 'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart'
replace_once(
    ui,
    '''  String _reminderOffsetTitle(int minutes) {
    if (minutes == 0) return 'В момент события';
    if (minutes < 60) return 'За $minutes мин';
    if (minutes % 1440 == 0) return 'За ${minutes ~/ 1440} дн.';
    if (minutes % 60 == 0) return 'За ${minutes ~/ 60} ч';
    return 'За ${minutes ~/ 60} ч ${minutes % 60} мин';
  }

''',
    '',
)

repo = 'lib/features/recruitment/data/recruitment_flight_repository.dart'
validation = '''    final reminderKeys = <String>{};
    for (final reminder in reminders) {
      if (reminder.eventKind != 'departure' && reminder.eventKind != 'arrival') {
        throw Exception('Некорректное событие уведомления');
      }
      if (reminder.offsetMinutes < 0 || reminder.offsetMinutes > 43200) {
        throw Exception('Уведомление можно поставить не более чем за 30 дней');
      }
      final key = '${reminder.eventKind}:${reminder.offsetMinutes}';
      if (!reminderKeys.add(key)) {
        throw Exception('Такое уведомление уже добавлено');
      }
      final eventAt = reminder.eventKind == 'arrival' ? arrivalAt : departureAt;
      if (eventAt == null) {
        throw Exception('Для уведомления о прибытии укажите время прибытия');
      }
      if (!reminder.isSent &&
          !eventAt
              .subtract(Duration(minutes: reminder.offsetMinutes))
              .isAfter(DateTime.now())) {
        throw Exception('Время одного из уведомлений уже прошло');
      }
    }

'''
replace_once(
    repo,
    '''    if (arrivalAt != null && !arrivalAt.isAfter(departureAt)) {
      throw Exception('Прибытие должно быть позже вылета');
    }

    final newAttachmentCount =''',
    '''    if (arrivalAt != null && !arrivalAt.isAfter(departureAt)) {
      throw Exception('Прибытие должно быть позже вылета');
    }

''' + validation + '''    final newAttachmentCount =''',
)
replace_once(repo, validation, '')

print('feature cleanup applied')
