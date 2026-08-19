from pathlib import Path
import re


def sub_once(path: str, pattern: str, replacement: str) -> None:
    file = Path(path)
    text = file.read_text()
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Expected one match in {path}, got {count}')
    file.write_text(updated)


model = 'lib/features/recruitment/models/recruitment_flight_models.dart'
sub_once(
    model,
    r'class RecruitmentFlightReminder \{.*?\n\}\n\nclass RecruitmentFlight \{',
    '''class RecruitmentFlightReminder {
  final String id;
  final String companyId;
  final String flightId;
  final String eventKind;
  final String title;
  final DateTime remindAt;
  final DateTime? sentAt;

  const RecruitmentFlightReminder({
    this.id = '',
    this.companyId = '',
    this.flightId = '',
    this.eventKind = 'departure',
    this.title = '',
    required this.remindAt,
    this.sentAt,
  });

  bool get isSent => sentAt != null;
  bool get isArrival => eventKind == 'arrival';
  String get eventTitle => isArrival ? 'Прибытие' : 'Отправление';
  String get displayTitle => title.trim().isEmpty ? eventTitle : title.trim();

  String get label {
    final local = remindAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'event_kind': eventKind,
    'reminder_title': title.trim(),
    'remind_at': remindAt.toUtc().toIso8601String(),
  };

  factory RecruitmentFlightReminder.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final rawEvent = map['event_kind']?.toString().trim() ?? '';
    return RecruitmentFlightReminder(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      eventKind: rawEvent == 'arrival' ? 'arrival' : 'departure',
      title: map['reminder_title']?.toString() ?? '',
      remindAt:
          optionalDate(map['remind_at']) ??
          optionalDate(map['created_at']) ??
          DateTime.now(),
      sentAt: optionalDate(map['sent_at']),
    );
  }
}

class RecruitmentFlight {''',
)

repo = 'lib/features/recruitment/data/recruitment_flight_repository.dart'
sub_once(
    repo,
    r'(    final reminderKeys = <String>\{\};\n    for \(final reminder in reminders\) \{\n)',
    r'''\1      if (reminder.eventKind != 'departure' && reminder.eventKind != 'arrival') {
        throw Exception('Выберите отправление или прибытие');
      }
      if (reminder.title.trim().isEmpty) {
        throw Exception('Укажите название уведомления');
      }
      if (reminder.title.trim().length > 120) {
        throw Exception('Название уведомления должно быть короче 120 символов');
      }
      if (reminder.eventKind == 'arrival' && arrivalAt == null) {
        throw Exception('Для уведомления о прибытии укажите время прибытия');
      }
''',
)

screen = 'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart'
sub_once(
    screen,
    r'  Future<void> addReminder\(\) async \{.*?\n  \}\n\n  Widget buildRemindersCard\(\)',
    '''  Future<void> addReminder() async {
    final titleController = TextEditingController();
    var selectedEvent = 'departure';
    final setup = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Новое уведомление'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Событие', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(
                      value: 'departure',
                      icon: Icon(Icons.flight_takeoff_rounded),
                      label: Text('Отправление'),
                    ),
                    ButtonSegment<String>(
                      value: 'arrival',
                      icon: Icon(Icons.flight_land_rounded),
                      label: Text('Прибытие'),
                    ),
                  ],
                  selected: <String>{selectedEvent},
                  onSelectionChanged: (values) =>
                      setDialogState(() => selectedEvent = values.first),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Название уведомления',
                    hintText: 'Например: проверить регистрацию',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: titleController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(<String, String>{
                        'event_kind': selectedEvent,
                        'title': titleController.text.trim(),
                      }),
              child: const Text('Далее'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (setup == null || !mounted) return;

    final eventKind = setup['event_kind'] ?? 'departure';
    final title = setup['title']?.trim() ?? '';
    if (eventKind == 'arrival' && arrivalAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите время прибытия рейса')),
      );
      return;
    }

    final now = DateTime.now();
    final eventAt = eventKind == 'arrival' ? arrivalAt : departureAt;
    final suggested = eventAt != null && eventAt.isAfter(now)
        ? eventAt
        : now.add(const Duration(hours: 1));
    final initial = DateTime(
      suggested.year,
      suggested.month,
      suggested.day,
      suggested.hour,
      suggested.minute,
    );
    final value = await chooseDateTime(initial);
    if (value == null || !mounted) return;

    final normalized = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
    if (!normalized.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите будущие дату и время уведомления')),
      );
      return;
    }
    final duplicate = reminders.any((item) {
      final current = item.remindAt.toLocal();
      return current.year == normalized.year &&
          current.month == normalized.month &&
          current.day == normalized.day &&
          current.hour == normalized.hour &&
          current.minute == normalized.minute;
    });
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Уведомление на это время уже добавлено')),
      );
      return;
    }
    setState(
      () => reminders.add(
        RecruitmentFlightReminder(
          eventKind: eventKind,
          title: title,
          remindAt: normalized,
        ),
      ),
    );
  }

  Widget buildRemindersCard()''',
)

sub_once(
    screen,
    r'''                          Text\(\n                            reminder\.label,\n                            style: const TextStyle\(fontWeight: FontWeight\.w800\),\n                          \),\n                          if \(reminder\.isSent\)''',
    '''                          Text(
                            reminder.displayTitle,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${reminder.eventTitle} · ${reminder.label}',
                            style: TextStyle(
                              color: AppAdaptivePalette.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (reminder.isSent)''',
)

test = 'test/flight_reminders_timesheet_period_test.dart'
sub_once(
    test,
    r'''  test\('flight reminder stores exact chosen date and time', \(\) \{.*?\n  \}\);''',
    '''  test('flight reminder stores event, title and exact chosen date and time', () {
    final reminder = RecruitmentFlightReminder(
      eventKind: 'arrival',
      title: 'Встретить сотрудника',
      remindAt: DateTime(2026, 8, 25, 18, 30),
    );

    expect(reminder.eventTitle, 'Прибытие');
    expect(reminder.displayTitle, 'Встретить сотрудника');
    expect(reminder.label, '25.08.2026 · 18:30');
    expect(reminder.toPayload()['event_kind'], 'arrival');
    expect(reminder.toPayload()['reminder_title'], 'Встретить сотрудника');
    expect(
      reminder.toPayload()['remind_at'],
      reminder.remindAt.toUtc().toIso8601String(),
    );
  });''',
)
sub_once(
    test,
    r'''  test\('flight editor asks only for reminder date and time', \(\) \{.*?\n  \}\);''',
    '''  test('flight editor keeps event choice, custom title and exact reminder time', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'Добавить уведомление'"));
    expect(source, contains("labelText: 'Название уведомления'"));
    expect(source, contains("Text('Отправление')"));
    expect(source, contains("Text('Прибытие')"));
    expect(source, contains('eventKind: eventKind'));
    expect(source, contains('title: title'));
    expect(source, isNot(contains("'За 15 минут'")));
    expect(source, isNot(contains("'За 3 часа'")));
    expect(source, isNot(contains("'За 24 часа'")));
    expect(source, isNot(contains("'Свой вариант'")));
    expect(source, isNot(contains("'Напомнить сотруднику'")));
    expect(source, contains('Future<void> chooseArrival() async'));
    expect(source, contains("'Убрать время прибытия'"));
  });''',
)
