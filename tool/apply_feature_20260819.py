from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'pattern not found in {path}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


# ---------------------------------------------------------------------------
# Flight models
# ---------------------------------------------------------------------------
models = 'lib/features/recruitment/models/recruitment_flight_models.dart'
insert_before = 'class RecruitmentFlight {\n'
reminder_model = r'''class RecruitmentFlightReminder {
  final String id;
  final String companyId;
  final String flightId;
  final String eventKind;
  final int offsetMinutes;
  final DateTime? sentAt;

  const RecruitmentFlightReminder({
    this.id = '',
    this.companyId = '',
    this.flightId = '',
    required this.eventKind,
    required this.offsetMinutes,
    this.sentAt,
  });

  bool get isArrival => eventKind == 'arrival';
  bool get isSent => sentAt != null;

  DateTime? eventAt(RecruitmentFlight flight) =>
      isArrival ? flight.arrivalAt : flight.departureAt;

  DateTime? triggerAt(RecruitmentFlight flight) =>
      eventAt(flight)?.subtract(Duration(minutes: offsetMinutes));

  String get label {
    final event = isArrival ? 'прибытия' : 'отправления';
    if (offsetMinutes == 0) return 'В момент $event';
    return 'За ${_offsetTitle(offsetMinutes)} до $event';
  }

  static String _offsetTitle(int minutes) {
    if (minutes < 60) return '$minutes мин';
    if (minutes % 1440 == 0) {
      final days = minutes ~/ 1440;
      return '$days ${days == 1 ? 'день' : days < 5 ? 'дня' : 'дней'}';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (rest == 0) return '$hours ч';
    return '$hours ч $rest мин';
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'event_kind': eventKind,
    'offset_minutes': offsetMinutes,
  };

  factory RecruitmentFlightReminder.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    final rawOffset = map['offset_minutes'];
    final offset = switch (rawOffset) {
      int value => value,
      num value => value.toInt(),
      _ => int.tryParse(rawOffset?.toString() ?? '') ?? 0,
    };
    return RecruitmentFlightReminder(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      eventKind: map['event_kind']?.toString() == 'arrival'
          ? 'arrival'
          : 'departure',
      offsetMinutes: offset,
      sentAt: optionalDate(map['sent_at']),
    );
  }
}

'''
replace_once(models, insert_before, reminder_model + insert_before)
replace_once(
    models,
    '''class RecruitmentFlightEntry {
  final RecruitmentFlight flight;
  final RecruitmentFlightCandidate candidate;
  final List<RecruitmentFlightTicket> tickets;

  const RecruitmentFlightEntry({
    required this.flight,
    required this.candidate,
    this.tickets = const <RecruitmentFlightTicket>[],
  });
}''',
    '''class RecruitmentFlightEntry {
  final RecruitmentFlight flight;
  final RecruitmentFlightCandidate candidate;
  final List<RecruitmentFlightTicket> tickets;
  final List<RecruitmentFlightReminder> reminders;

  const RecruitmentFlightEntry({
    required this.flight,
    required this.candidate,
    this.tickets = const <RecruitmentFlightTicket>[],
    this.reminders = const <RecruitmentFlightReminder>[],
  });
}''',
)

# ---------------------------------------------------------------------------
# Flight repository
# ---------------------------------------------------------------------------
repo = 'lib/features/recruitment/data/recruitment_flight_repository.dart'
fetch_tickets_marker = '''  static Future<List<RecruitmentFlightTicket>> fetchFlightTickets({
'''
fetch_reminders = r'''  static Future<List<RecruitmentFlightReminder>> fetchFlightReminders({
    required String companyId,
  }) async {
    final cleanCompanyId = companyId.trim();
    if (cleanCompanyId.isEmpty) return const <RecruitmentFlightReminder>[];
    final rows = await _client
        .from('recruitment_flight_reminders')
        .select()
        .eq('company_id', cleanCompanyId)
        .order('created_at', ascending: true)
        .limit(10000);
    return rows
        .map<RecruitmentFlightReminder>(
          (row) => RecruitmentFlightReminder.fromMap(_map(row)),
        )
        .where((reminder) => reminder.flightId.isNotEmpty)
        .toList(growable: false);
  }

'''
replace_once(repo, fetch_tickets_marker, fetch_reminders + fetch_tickets_marker)
replace_once(
    repo,
    '''      fetchFlights(companyId: companyId),
      fetchFlightTickets(companyId: companyId),
    ]);
    final candidates = results[0] as List<RecruitmentFlightCandidate>;
    final flights = results[1] as List<RecruitmentFlight>;
    final tickets = results[2] as List<RecruitmentFlightTicket>;''',
    '''      fetchFlights(companyId: companyId),
      fetchFlightTickets(companyId: companyId),
      fetchFlightReminders(companyId: companyId),
    ]);
    final candidates = results[0] as List<RecruitmentFlightCandidate>;
    final flights = results[1] as List<RecruitmentFlight>;
    final tickets = results[2] as List<RecruitmentFlightTicket>;
    final reminders = results[3] as List<RecruitmentFlightReminder>;''',
)
replace_once(
    repo,
    '''    final ticketsByFlight = <String, List<RecruitmentFlightTicket>>{};
    for (final ticket in tickets) {
      ticketsByFlight
          .putIfAbsent(ticket.flightId, () => <RecruitmentFlightTicket>[])
          .add(ticket);
    }
    final entries = flights''',
    '''    final ticketsByFlight = <String, List<RecruitmentFlightTicket>>{};
    for (final ticket in tickets) {
      ticketsByFlight
          .putIfAbsent(ticket.flightId, () => <RecruitmentFlightTicket>[])
          .add(ticket);
    }
    final remindersByFlight = <String, List<RecruitmentFlightReminder>>{};
    for (final reminder in reminders) {
      remindersByFlight
          .putIfAbsent(reminder.flightId, () => <RecruitmentFlightReminder>[])
          .add(reminder);
    }
    final entries = flights''',
)
replace_once(
    repo,
    '''          return RecruitmentFlightEntry(
            flight: flight,
            candidate: candidate,
            tickets: List<RecruitmentFlightTicket>.unmodifiable(attachments),
          );''',
    '''          return RecruitmentFlightEntry(
            flight: flight,
            candidate: candidate,
            tickets: List<RecruitmentFlightTicket>.unmodifiable(attachments),
            reminders: List<RecruitmentFlightReminder>.unmodifiable(
              remindersByFlight[flight.id] ?? const <RecruitmentFlightReminder>[],
            ),
          );''',
)
replace_once(
    repo,
    '''    String flightNumber = '',
    bool remindDayBefore = true,
    bool remindThreeHours = true,
    String notes = '',
''',
    '''    String flightNumber = '',
    List<RecruitmentFlightReminder> reminders =
        const <RecruitmentFlightReminder>[],
    String notes = '',
''',
)
replace_once(
    repo,
    '''      'flight_number': flightNumber.trim().toUpperCase(),
      'remind_day_before': remindDayBefore,
      'remind_three_hours': remindThreeHours,
      'notes': notes.trim(),''',
    '''      'flight_number': flightNumber.trim().toUpperCase(),
      'remind_day_before': false,
      'remind_three_hours': false,
      'notes': notes.trim(),''',
)
replace_once(
    repo,
    '''    final result = RecruitmentFlight.fromMap(_map(row));

    if (uploadedAttachments.isNotEmpty) {''',
    '''    final result = RecruitmentFlight.fromMap(_map(row));

    final reminderKeys = <String>{};
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

    await _client.rpc(
      'replace_recruitment_flight_reminders',
      params: <String, dynamic>{
        'p_flight_id': result.id,
        'p_reminders': reminders.map((item) => item.toPayload()).toList(),
      },
    );

    if (uploadedAttachments.isNotEmpty) {''',
)

# ---------------------------------------------------------------------------
# Flight editor UI
# ---------------------------------------------------------------------------
ui = 'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart'
replace_once(
    ui,
    '''  late bool remindDayBefore;
  late bool remindThreeHours;
  final List<RecruitmentFlightTicketUpload> pendingTickets =''',
    '''  late List<RecruitmentFlightReminder> reminders;
  final List<RecruitmentFlightTicketUpload> pendingTickets =''',
)
replace_once(
    ui,
    '''    remindDayBefore = entry?.flight.remindDayBefore ?? true;
    remindThreeHours = entry?.flight.remindThreeHours ?? true;''',
    '''    reminders = List<RecruitmentFlightReminder>.from(
      entry?.reminders ?? const <RecruitmentFlightReminder>[],
    );''',
)
replace_once(
    ui,
    '''  Future<void> chooseTickets() async {''',
    r'''  String _reminderOffsetTitle(int minutes) {
    if (minutes == 0) return 'В момент события';
    if (minutes < 60) return 'За $minutes мин';
    if (minutes % 1440 == 0) return 'За ${minutes ~/ 1440} дн.';
    if (minutes % 60 == 0) return 'За ${minutes ~/ 60} ч';
    return 'За ${minutes ~/ 60} ч ${minutes % 60} мин';
  }

  Future<void> addReminder() async {
    var eventKind = 'departure';
    var offsetMinutes = 180;
    final customController = TextEditingController(text: '90');
    String? validationText;
    final result = await showModalBottomSheet<RecruitmentFlightReminder>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final bottom = MediaQuery.viewInsetsOf(context).bottom;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
              child: PremiumWorkCard(
                radius: 26,
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Добавить уведомление',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: eventKind,
                      decoration: const InputDecoration(
                        labelText: 'Событие',
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem(
                          value: 'departure',
                          child: Text('Отправление'),
                        ),
                        DropdownMenuItem(
                          value: 'arrival',
                          enabled: arrivalAt != null,
                          child: Text(
                            arrivalAt == null
                                ? 'Прибытие — сначала укажите время'
                                : 'Прибытие',
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          eventKind = value;
                          validationText = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: offsetMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Когда напомнить',
                        prefixIcon: Icon(Icons.schedule_rounded),
                      ),
                      items: const <int>[0, 15, 30, 60, 180, 360, 720, 1440, 2880, -1]
                          .map(
                            (value) => DropdownMenuItem<int>(
                              value: value,
                              child: Text(
                                value == -1
                                    ? 'Свой вариант'
                                    : _reminderPresetLabel(value),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          offsetMinutes = value;
                          validationText = null;
                        });
                      },
                    ),
                    if (offsetMinutes == -1) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'За сколько минут',
                          hintText: 'Например, 90',
                          prefixIcon: Icon(Icons.edit_calendar_outlined),
                        ),
                      ),
                    ],
                    if (validationText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationText!,
                        style: TextStyle(
                          color: AppAdaptivePalette.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        final offset = offsetMinutes == -1
                            ? int.tryParse(customController.text.trim())
                            : offsetMinutes;
                        if (offset == null || offset < 0 || offset > 43200) {
                          setSheetState(() => validationText =
                              'Укажите время от 0 минут до 30 дней');
                          return;
                        }
                        final eventAt = eventKind == 'arrival'
                            ? arrivalAt
                            : departureAt;
                        if (eventAt == null) {
                          setSheetState(() => validationText =
                              'Сначала укажите время прибытия');
                          return;
                        }
                        final triggerAt = eventAt.subtract(
                          Duration(minutes: offset),
                        );
                        if (!triggerAt.isAfter(DateTime.now())) {
                          setSheetState(() => validationText =
                              'Это уведомление должно было сработать раньше. Выберите другое время.');
                          return;
                        }
                        final duplicate = reminders.any(
                          (item) =>
                              item.eventKind == eventKind &&
                              item.offsetMinutes == offset,
                        );
                        if (duplicate) {
                          setSheetState(() => validationText =
                              'Такое уведомление уже добавлено');
                          return;
                        }
                        Navigator.pop(
                          sheetContext,
                          RecruitmentFlightReminder(
                            eventKind: eventKind,
                            offsetMinutes: offset,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_alert_rounded),
                      label: const Text('Добавить'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    customController.dispose();
    if (result != null && mounted) {
      setState(() => reminders.add(result));
    }
  }

  static String _reminderPresetLabel(int minutes) => switch (minutes) {
    0 => 'В момент события',
    15 => 'За 15 минут',
    30 => 'За 30 минут',
    60 => 'За 1 час',
    180 => 'За 3 часа',
    360 => 'За 6 часов',
    720 => 'За 12 часов',
    1440 => 'За 24 часа',
    2880 => 'За 2 дня',
    _ => 'За $minutes минут',
  };

  Widget buildRemindersCard() {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Уведомления',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            reminders.isEmpty
                ? 'Уведомления не добавлены. Можно поставить несколько напоминаний перед отправлением или прибытием.'
                : 'Добавлено: ${reminders.length}',
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (reminders.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...reminders.asMap().entries.map((entry) {
              final reminder = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      reminder.isArrival
                          ? Icons.flight_land_rounded
                          : Icons.flight_takeoff_rounded,
                      color: AppAdaptivePalette.accentStrong,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reminder.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (reminder.isSent)
                            Text(
                              'Уже отправлено',
                              style: TextStyle(
                                color: AppAdaptivePalette.textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Удалить уведомление',
                      onPressed: saving
                          ? null
                          : () => setState(() => reminders.removeAt(entry.key)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
          ],
          OutlinedButton.icon(
            onPressed: saving || reminders.length >= 20 ? null : addReminder,
            icon: const Icon(Icons.add_alert_rounded),
            label: const Text('Добавить уведомление'),
          ),
        ],
      ),
    );
  }

  Future<void> chooseTickets() async {''',
)
replace_once(
    ui,
    '''        flightNumber: flightNumberController.text,
        remindDayBefore: remindDayBefore,
        remindThreeHours: remindThreeHours,
        notes: notesController.text,''',
    '''        flightNumber: flightNumberController.text,
        reminders: List<RecruitmentFlightReminder>.unmodifiable(reminders),
        notes: notesController.text,''',
)
replace_once(
    ui,
    '''          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: remindDayBefore,
            onChanged: saving
                ? null
                : (value) => setState(() => remindDayBefore = value),
            title: const Text(
              'Напомнить за сутки',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Сотруднику придёт уведомление за 24 часа.'),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: remindThreeHours,
            onChanged: saving
                ? null
                : (value) => setState(() => remindThreeHours = value),
            title: const Text(
              'Напомнить за 3 часа',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text(
              'Повторное напоминание перед поездкой в аэропорт.',
            ),
          ),
          const SizedBox(height: 8),''',
    '''          const SizedBox(height: 12),
          buildRemindersCard(),
          const SizedBox(height: 12),''',
)

# ---------------------------------------------------------------------------
# Attendance repository: exact period for one employee and actual payment date.
# ---------------------------------------------------------------------------
attendance = 'lib/data/attendance_repository.dart'
replace_once(
    attendance,
    '''import '../models/employee.dart';
import '../models/monthly_timesheet_row.dart';''',
    '''import '../models/employee.dart';
import '../models/employee_timesheet_period_row.dart';
import '../models/monthly_timesheet_row.dart';''',
)
period_marker = '''  static Future<List<PeriodTimesheetRow>> fetchPeriodTimesheet({
'''
period_method = r'''  static Future<EmployeeTimesheetPeriodRow> fetchTimesheetForEmployeePeriod({
    required Employee employee,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final cleanStart = DateTime(startDate.year, startDate.month, startDate.day);
    final cleanEnd = DateTime(endDate.year, endDate.month, endDate.day);
    if (cleanEnd.isBefore(cleanStart)) {
      throw ArgumentError('Конец периода не может быть раньше начала');
    }
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      return EmployeeTimesheetPeriodRow(
        employee: employee,
        startDate: cleanStart,
        endDate: cleanEnd,
        shiftsByDate: const <String, double>{},
        paid: 0,
      );
    }

    final data = await Future.wait<dynamic>([
      _fetchAttendanceRows(
        startDate: cleanStart,
        endDate: cleanEnd,
        employeeIds: <String>[employeeId],
      ),
      _client
          .from('payments')
          .select('amount')
          .eq('employee_id', employeeId)
          .gte('payment_date', dateKey(cleanStart))
          .lte('payment_date', dateKey(cleanEnd))
          .isFilter('deleted_at', null),
    ]);
    final attendanceRows = data[0] as List<Map<String, dynamic>>;
    final paymentRows = data[1] as List<dynamic>;
    final shiftsByDate = <String, double>{};
    for (final row in attendanceRows) {
      final workDateText = row['work_date']?.toString();
      if (workDateText == null || workDateText.isEmpty) continue;
      shiftsByDate[workDateText] = _toDouble(row['shifts']);
    }
    var paid = 0.0;
    for (final row in paymentRows) {
      paid += _toDouble(row['amount']);
    }
    return EmployeeTimesheetPeriodRow(
      employee: employee,
      startDate: cleanStart,
      endDate: cleanEnd,
      shiftsByDate: shiftsByDate,
      paid: paid,
    );
  }

'''
replace_once(attendance, period_marker, period_method + period_marker)

print('feature patches applied')
