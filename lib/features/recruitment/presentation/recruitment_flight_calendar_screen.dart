import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_flight_repository.dart';
import '../models/recruitment_flight_models.dart';
import 'recruitment_mobilization_screen.dart';

class RecruitmentFlightCalendarScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentFlightCalendarScreen({super.key, required this.profile});

  @override
  State<RecruitmentFlightCalendarScreen> createState() =>
      _RecruitmentFlightCalendarScreenState();
}

class _RecruitmentFlightCalendarScreenState
    extends State<RecruitmentFlightCalendarScreen> {
  late Future<RecruitmentFlightCalendarData> future;
  DateTime visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDay = _dateOnly(DateTime.now());
  final Set<String> reminderBusyIds = <String>{};
  final Set<String> statusBusyIds = <String>{};

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<RecruitmentFlightCalendarData> load() {
    return RecruitmentFlightRepository.fetchCalendar(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  String monthTitle(DateTime value) {
    const months = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  String dateTitle(DateTime value) {
    const weekdays = <String>[
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}, ${weekdays[value.weekday - 1]}';
  }

  String timeTitle(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String ticketCountText(int count) => switch (count) {
    1 => '1 билет',
    2 || 3 || 4 => '$count билета',
    _ => '$count билетов',
  };

  bool sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  void changeMonth(int offset) {
    setState(() {
      visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + offset);
      selectedDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    });
  }

  Future<void> openEditor(
    RecruitmentFlightCalendarData data, {
    RecruitmentFlightEntry? entry,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      CupertinoPageRoute<bool>(
        builder: (_) => RecruitmentFlightEditorScreen(
          profile: widget.profile,
          candidates: data.candidates,
          entry: entry,
        ),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> openTicket(RecruitmentFlightTicket ticket) async {
    try {
      final url = await RecruitmentFlightRepository.createFlightTicketUrl(ticket);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) throw Exception('Не удалось открыть билет');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть билет: $error')),
      );
    }
  }

  Future<void> openTickets(RecruitmentFlightEntry entry) async {
    final tickets = entry.tickets;
    if (tickets.isEmpty) return;
    if (tickets.length == 1) {
      await openTicket(tickets.first);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final ticket = tickets[index];
          return ListTile(
            leading: const Icon(Icons.confirmation_number_outlined),
            title: Text(
              ticket.originalName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Билет ${index + 1} из ${tickets.length}'),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              await openTicket(ticket);
            },
          );
        },
      ),
    );
  }

  Future<void> sendReminder(RecruitmentFlightEntry entry) async {
    if (reminderBusyIds.contains(entry.flight.id)) return;
    setState(() => reminderBusyIds.add(entry.flight.id));
    try {
      final result = await RecruitmentFlightRepository.sendReminder(entry);
      if (!mounted) return;
      final channels = <String>[
        if (result.hasAppRecipient) 'приложение',
        if (entry.candidate.canMessageInMax) 'MAX',
        if (entry.candidate.canMessageInTelegram) 'Telegram',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            channels.isEmpty
                ? 'Напоминание записано, но сотрудник ещё не подключён к приложению или боту'
                : 'Напоминание отправлено: ${channels.join(', ')}',
          ),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить напоминание: $error')),
      );
    } finally {
      if (mounted) setState(() => reminderBusyIds.remove(entry.flight.id));
    }
  }

  Future<void> changeStatus(
    RecruitmentFlightEntry entry,
    String status,
  ) async {
    if (statusBusyIds.contains(entry.flight.id)) return;
    setState(() => statusBusyIds.add(entry.flight.id));
    try {
      await RecruitmentFlightRepository.setStatus(
        flight: entry.flight,
        status: status,
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить статус: $error')),
      );
    } finally {
      if (mounted) setState(() => statusBusyIds.remove(entry.flight.id));
    }
  }

  List<RecruitmentFlightEntry> entriesForDay(
    List<RecruitmentFlightEntry> entries,
    DateTime day,
  ) {
    return entries
        .where((entry) => sameDay(entry.flight.departureAt, day))
        .toList(growable: false)
      ..sort(
        (first, second) =>
            first.flight.departureAt.compareTo(second.flight.departureAt),
      );
  }

  Widget calendar(
    RecruitmentFlightCalendarData data, {
    required bool compact,
  }) {
    final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leading = firstDay.weekday - 1;
    final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
    const weekdays = <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return PremiumWorkCard(
      radius: 25,
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Предыдущий месяц',
                onPressed: () => changeMonth(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  monthTitle(visibleMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Следующий месяц',
                onPressed: () => changeMonth(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: compact ? 0.86 : 1.0,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemCount: 7 + cells,
            itemBuilder: (context, index) {
              if (index < 7) {
                return Center(
                  child: Text(
                    weekdays[index],
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }
              final dayIndex = index - 7 - leading + 1;
              if (dayIndex < 1 || dayIndex > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                dayIndex,
              );
              final flights = entriesForDay(data.flights, day);
              final selected = sameDay(day, selectedDay);
              final today = sameDay(day, DateTime.now());
              return InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: () => setState(() => selectedDay = day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppAdaptivePalette.selectedSurface
                        : AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: selected
                          ? AppAdaptivePalette.accentStrong
                          : today
                          ? AppAdaptivePalette.accentStrong.withValues(
                              alpha: 0.45,
                            )
                          : AppAdaptivePalette.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dayIndex',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? AppAdaptivePalette.accentStrong
                              : AppAdaptivePalette.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (flights.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppAdaptivePalette.accentStrong.withValues(
                              alpha: 0.14,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            flights.length == 1
                                ? timeTitle(flights.first.flight.departureAt)
                                : 'Вылетов: ${flights.length}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppAdaptivePalette.accentStrong,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget flightCard(
    RecruitmentFlightEntry entry,
    RecruitmentFlightCalendarData data,
  ) {
    final flight = entry.flight;
    final ticketCount = entry.tickets.length;
    final reminderBusy = reminderBusyIds.contains(flight.id);
    final statusBusy = statusBusyIds.contains(flight.id);
    final now = DateTime.now();
    final timeUntil = flight.departureAt.difference(now);
    final urgent = timeUntil.isNegative
        ? false
        : timeUntil <= const Duration(hours: 24);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: flight.isCancelled
                        ? AppAdaptivePalette.danger.withValues(alpha: 0.12)
                        : urgent
                        ? AppAdaptivePalette.warning.withValues(alpha: 0.14)
                        : AppAdaptivePalette.accentStrong.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    flight.isCancelled
                        ? Icons.airplanemode_inactive_rounded
                        : Icons.flight_takeoff_rounded,
                    color: flight.isCancelled
                        ? AppAdaptivePalette.danger
                        : urgent
                        ? AppAdaptivePalette.warning
                        : AppAdaptivePalette.accentStrong,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.candidate.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        flight.routeTitle,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateTitle(flight.departureAt)} · ${timeTitle(flight.departureAt)}'
                        '${flight.flightNumber.isEmpty ? '' : ' · ${flight.flightNumber}'}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (entry.candidate.objectName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          entry.candidate.objectName,
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !statusBusy,
                  tooltip: 'Статус вылета',
                  onSelected: (value) => changeStatus(entry, value),
                  itemBuilder: (_) => const <PopupMenuEntry<String>>[
                    PopupMenuItem(value: 'scheduled', child: Text('Запланирован')),
                    PopupMenuItem(
                      value: 'checked_in',
                      child: Text('Регистрация пройдена'),
                    ),
                    PopupMenuItem(value: 'departed', child: Text('Вылетел')),
                    PopupMenuItem(value: 'arrived', child: Text('Прибыл')),
                    PopupMenuItem(value: 'cancelled', child: Text('Отменён')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: statusBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_horiz_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _FlightChip(
                  icon: Icons.flag_outlined,
                  text: flight.statusTitle,
                ),
                if (flight.remindDayBefore)
                  const _FlightChip(
                    icon: Icons.notifications_active_outlined,
                    text: 'За сутки',
                  ),
                if (flight.remindThreeHours)
                  const _FlightChip(
                    icon: Icons.alarm_outlined,
                    text: 'За 3 часа',
                  ),
                _FlightChip(
                  icon: ticketCount > 0
                      ? Icons.attachment_rounded
                      : Icons.warning_amber_rounded,
                  text: ticketCount > 0
                      ? ticketCountText(ticketCount)
                      : 'Нет билета',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ticketCount > 0 ? () => openTickets(entry) : null,
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: Text(
                      ticketCount > 1 ? 'Билеты ($ticketCount)' : 'Билет',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => openEditor(data, entry: entry),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Изменить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: reminderBusy || flight.isCancelled || flight.isCompleted
                  ? null
                  : () => sendReminder(entry),
              icon: reminderBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text('Напомнить сотруднику'),
            ),
          ],
        ),
      ),
    );
  }

  Widget flightList(
    RecruitmentFlightCalendarData data,
    List<RecruitmentFlightEntry> entries,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateTitle(selectedDay),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${entries.length}',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        if (entries.isEmpty)
          const _FlightMessage(
            icon: Icons.event_available_outlined,
            text: 'На выбранную дату вылетов нет.',
          )
        else
          ...entries.map((entry) => flightCard(entry, data)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Календарь вылетов',
      subtitle: 'Билеты, маршруты и напоминания сотрудникам',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: 'Подготовка выхода',
            onPressed: () => Navigator.of(context).push<void>(
              CupertinoPageRoute<void>(
                builder: (_) => RecruitmentMobilizationScreen(
                  profile: widget.profile,
                ),
              ),
            ),
            icon: const Icon(Icons.assignment_turned_in_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: FutureBuilder<RecruitmentFlightCalendarData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _FlightMessage(
              icon: Icons.error_outline_rounded,
              text: 'Не удалось загрузить календарь: ${snapshot.error}',
            );
          }
          final data =
              snapshot.data ??
              const RecruitmentFlightCalendarData(
                candidates: <RecruitmentFlightCandidate>[],
                flights: <RecruitmentFlightEntry>[],
              );
          final selected = entriesForDay(data.flights, selectedDay);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FlightMessage(
                icon: Icons.info_outline_rounded,
                text:
                    'После сохранения билетов вылет появляется в календаре. Система создаёт напоминания за сутки и за 3 часа, а HR может отправить напоминание вручную.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: data.candidates.isEmpty
                    ? null
                    : () => openEditor(data),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить вылет и билеты'),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        calendar(data, compact: true),
                        const SizedBox(height: 16),
                        flightList(data, selected),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: calendar(data, compact: false)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: flightList(data, selected)),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class RecruitmentFlightEditorScreen extends StatefulWidget {
  final AppUserProfile profile;
  final List<RecruitmentFlightCandidate> candidates;
  final RecruitmentFlightEntry? entry;

  const RecruitmentFlightEditorScreen({
    super.key,
    required this.profile,
    required this.candidates,
    this.entry,
  });

  @override
  State<RecruitmentFlightEditorScreen> createState() =>
      _RecruitmentFlightEditorScreenState();
}

class _RecruitmentFlightEditorScreenState
    extends State<RecruitmentFlightEditorScreen> {
  RecruitmentFlightCandidate? candidate;
  late DateTime departureAt;
  DateTime? arrivalAt;
  late final TextEditingController originController;
  late final TextEditingController destinationController;
  late final TextEditingController flightNumberController;
  late final TextEditingController notesController;
  late List<RecruitmentFlightReminder> reminders;
  final List<RecruitmentFlightTicketUpload> pendingTickets =
      <RecruitmentFlightTicketUpload>[];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    candidate = entry?.candidate;
    departureAt =
        entry?.flight.departureAt ??
        DateTime.now().add(const Duration(days: 1, hours: 3));
    arrivalAt = entry?.flight.arrivalAt;
    originController = TextEditingController(text: entry?.flight.origin ?? '');
    destinationController = TextEditingController(
      text: entry?.flight.destination ?? '',
    );
    flightNumberController = TextEditingController(
      text: entry?.flight.flightNumber ?? '',
    );
    notesController = TextEditingController(text: entry?.flight.notes ?? '');
    reminders = List<RecruitmentFlightReminder>.from(
      entry?.reminders ?? const <RecruitmentFlightReminder>[],
    );
  }

  @override
  void dispose() {
    originController.dispose();
    destinationController.dispose();
    flightNumberController.dispose();
    notesController.dispose();
    super.dispose();
  }

  String dateTimeText(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} · $hour:$minute';
  }

  Future<DateTime?> chooseDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> chooseDeparture() async {
    final value = await chooseDateTime(departureAt);
    if (value != null && mounted) setState(() => departureAt = value);
  }

  Future<void> chooseArrival() async {
    final value = await chooseDateTime(
      arrivalAt ?? departureAt.add(const Duration(hours: 3)),
    );
    if (value != null && mounted) setState(() => arrivalAt = value);
  }

  String _reminderOffsetTitle(int minutes) {
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

  Future<void> chooseTickets() async {
    final existingTickets =
        widget.entry?.tickets ?? const <RecruitmentFlightTicket>[];
    final remaining =
        RecruitmentFlightRepository.maxTicketsPerFlight -
        existingTickets.length -
        pendingTickets.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'К одному вылету можно прикрепить не больше ${RecruitmentFlightRepository.maxTicketsPerFlight} билетов',
          ),
        ),
      );
      return;
    }

    final files = await openFiles(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Билеты',
          extensions: <String>['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
        ),
      ],
    );
    if (files.isEmpty) return;

    final additions = <RecruitmentFlightTicketUpload>[];
    var totalBytes = pendingTickets.fold<int>(
      0,
      (sum, item) => sum + item.bytes.length,
    );
    var skippedByLimit = 0;
    var rejected = 0;

    for (final file in files) {
      if (additions.length >= remaining) {
        skippedByLimit++;
        continue;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty ||
          bytes.length > RecruitmentFlightRepository.maxTicketBytes) {
        rejected++;
        continue;
      }
      if (totalBytes + bytes.length >
          RecruitmentFlightRepository.maxTotalTicketBytes) {
        rejected++;
        continue;
      }
      final duplicate = pendingTickets.any(
        (item) => item.fileName == file.name && item.bytes.length == bytes.length,
      );
      if (duplicate) continue;
      totalBytes += bytes.length;
      additions.add(
        RecruitmentFlightTicketUpload(fileName: file.name, bytes: bytes),
      );
    }

    if (!mounted) return;
    setState(() => pendingTickets.addAll(additions));
    if (skippedByLimit > 0 || rejected > 0) {
      final details = <String>[
        if (skippedByLimit > 0)
          'не добавлено по лимиту: $skippedByLimit',
        if (rejected > 0) 'пропущено по размеру: $rejected',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(details.join(' · '))),
      );
    }
  }

  Future<void> save() async {
    if (saving) return;
    final selectedCandidate = candidate;
    if (selectedCandidate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите сотрудника или кандидата')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      await RecruitmentFlightRepository.saveFlight(
        flightId: widget.entry?.flight.id ?? '',
        candidate: selectedCandidate,
        departureAt: departureAt,
        arrivalAt: arrivalAt,
        origin: originController.text,
        destination: destinationController.text,
        flightNumber: flightNumberController.text,
        reminders: List<RecruitmentFlightReminder>.unmodifiable(reminders),
        notes: notesController.text,
        ticketUploads: List<RecruitmentFlightTicketUpload>.unmodifiable(
          pendingTickets,
        ),
        existing: widget.entry?.flight,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingTickets =
        widget.entry?.tickets ?? const <RecruitmentFlightTicket>[];
    final totalTicketCount = existingTickets.length + pendingTickets.length;
    return AppPage(
      title: widget.entry == null ? 'Новый вылет' : 'Изменить вылет',
      subtitle: 'Точный маршрут, время и купленные билеты',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<RecruitmentFlightCandidate>(
            initialValue: candidate,
            decoration: const InputDecoration(
              labelText: 'Сотрудник или кандидат',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            items: widget.candidates
                .map(
                  (item) => DropdownMenuItem<RecruitmentFlightCandidate>(
                    value: item,
                    child: Text(
                      '${item.fullName}${item.objectName.isEmpty ? '' : ' · ${item.objectName}'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: saving
                ? null
                : (value) => setState(() => candidate = value),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: originController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Откуда',
                    hintText: 'Москва',
                    prefixIcon: Icon(Icons.flight_takeoff_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: destinationController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Куда',
                    hintText: 'Мурманск',
                    prefixIcon: Icon(Icons.flight_land_outlined),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: flightNumberController,
            enabled: !saving,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Номер рейса',
              hintText: 'SU 1320',
              prefixIcon: Icon(Icons.airplane_ticket_outlined),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: saving ? null : chooseDeparture,
            icon: const Icon(Icons.event_outlined),
            label: Text('Вылет: ${dateTimeText(departureAt)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : chooseArrival,
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              arrivalAt == null
                  ? 'Указать время прибытия'
                  : 'Прибытие: ${dateTimeText(arrivalAt!)}',
            ),
          ),
          if (arrivalAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: saving
                    ? null
                    : () => setState(() => arrivalAt = null),
                child: const Text('Убрать время прибытия'),
              ),
            ),
          const SizedBox(height: 4),
          PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Купленные билеты',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  totalTicketCount == 0
                      ? 'Можно выбрать сразу несколько PDF или фотографий. Без хотя бы одного файла вылет не сохранится.'
                      : 'Прикреплено: $totalTicketCount из ${RecruitmentFlightRepository.maxTicketsPerFlight}',
                  style: TextStyle(
                    color: totalTicketCount == 0
                        ? AppAdaptivePalette.textMuted
                        : AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (existingTickets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...existingTickets.map(
                    (ticket) => _TicketFileRow(
                      fileName: ticket.originalName,
                      saved: true,
                    ),
                  ),
                ],
                if (pendingTickets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...pendingTickets.asMap().entries.map(
                    (item) => _TicketFileRow(
                      fileName: item.value.fileName,
                      saved: false,
                      onRemove: saving
                          ? null
                          : () => setState(
                              () => pendingTickets.removeAt(item.key),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed:
                      saving ||
                          totalTicketCount >=
                              RecruitmentFlightRepository.maxTicketsPerFlight
                      ? null
                      : chooseTickets,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    totalTicketCount == 0
                        ? 'Прикрепить билеты'
                        : 'Добавить ещё билеты',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          buildRemindersCard(),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            enabled: !saving,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Комментарий HR',
              hintText: 'Багаж, пересадка, кто встречает и другие детали',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(saving ? 'Сохраняем...' : 'Сохранить вылет'),
          ),
        ],
      ),
    );
  }
}

class _TicketFileRow extends StatelessWidget {
  final String fileName;
  final bool saved;
  final VoidCallback? onRemove;

  const _TicketFileRow({
    required this.fileName,
    required this.saved,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            saved ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
            size: 18,
            color: saved
                ? AppAdaptivePalette.accentStrong
                : AppAdaptivePalette.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  saved
                      ? 'Сохранён в календаре'
                      : 'Будет добавлен после сохранения',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Убрать файл',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class _FlightChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FlightChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppAdaptivePalette.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _FlightMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FlightMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
