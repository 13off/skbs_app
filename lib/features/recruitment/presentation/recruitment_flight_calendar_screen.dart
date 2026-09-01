import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_flight_repository.dart';
import '../models/recruitment_flight_models.dart';
import 'recruitment_mobilization_screen.dart';
import '../../../navigation/app_page_route.dart';

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
    final editorCandidates =
        entry == null ||
            data.candidates.any(
              (candidate) =>
                  candidate.applicationId == entry.candidate.applicationId,
            )
        ? data.candidates
        : <RecruitmentFlightCandidate>[entry.candidate, ...data.candidates];
    final saved = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        builder: (_) => RecruitmentFlightEditorScreen(
          profile: widget.profile,
          candidates: editorCandidates,
          entry: entry,
        ),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> openTicket(RecruitmentFlightTicket ticket) async {
    try {
      final url = await RecruitmentFlightRepository.createFlightTicketUrl(
        ticket,
      );
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

  Future<void> changeStatus(RecruitmentFlightEntry entry, String status) async {
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

  Widget calendar(RecruitmentFlightCalendarData data, {required bool compact}) {
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
                        : AppAdaptivePalette.accentStrong.withValues(
                            alpha: 0.12,
                          ),
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
                    PopupMenuItem(
                      value: 'scheduled',
                      child: Text('Запланирован'),
                    ),
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
                    onPressed: ticketCount > 0
                        ? () => openTickets(entry)
                        : null,
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
      subtitle: 'Билеты, маршруты и ваши уведомления',
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: 'Подготовка выхода',
            onPressed: () => Navigator.of(context).push<void>(
              AppPageRoute<void>(
                builder: (_) =>
                    RecruitmentMobilizationScreen(profile: widget.profile),
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
                    'Для нового вылета доступны только карточки из колонки «Куплен билет». После сохранения вылет появляется в календаре.',
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

class _FlightSegmentDraft {
  final TextEditingController originController;
  final TextEditingController destinationController;
  final TextEditingController flightNumberController;
  DateTime departureAt;
  DateTime? arrivalAt;

  _FlightSegmentDraft({
    required String origin,
    required String destination,
    required String flightNumber,
    required this.departureAt,
    required this.arrivalAt,
  })  : originController = TextEditingController(text: origin),
        destinationController = TextEditingController(text: destination),
        flightNumberController = TextEditingController(text: flightNumber);

  factory _FlightSegmentDraft.fromSegment(RecruitmentFlightSegment segment) =>
      _FlightSegmentDraft(
        origin: segment.origin,
        destination: segment.destination,
        flightNumber: segment.flightNumber,
        departureAt: segment.departureAt,
        arrivalAt: segment.arrivalAt,
      );

  RecruitmentFlightSegment toSegment() => RecruitmentFlightSegment(
        origin: originController.text.trim(),
        destination: destinationController.text.trim(),
        flightNumber: flightNumberController.text.trim(),
        departureAt: departureAt,
        arrivalAt: arrivalAt,
      );

  void dispose() {
    originController.dispose();
    destinationController.dispose();
    flightNumberController.dispose();
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
  late final List<_FlightSegmentDraft> flightSegments;
  late final TextEditingController notesController;
  late List<RecruitmentFlightReminder> reminders;
  final List<RecruitmentFlightTicketUpload> pendingTickets =
      <RecruitmentFlightTicketUpload>[];
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    candidate =
        entry?.candidate ??
        (widget.candidates.length == 1 ? widget.candidates.first : null);
    final storedSegments =
        entry?.flight.segments ?? const <RecruitmentFlightSegment>[];
    if (storedSegments.isNotEmpty) {
      flightSegments = storedSegments
          .map(_FlightSegmentDraft.fromSegment)
          .toList(growable: true);
    } else if (entry != null) {
      flightSegments = <_FlightSegmentDraft>[
        _FlightSegmentDraft(
          origin: entry.flight.origin,
          destination: entry.flight.destination,
          flightNumber: entry.flight.flightNumber,
          departureAt: entry.flight.departureAt,
          arrivalAt: entry.flight.arrivalAt,
        ),
      ];
    } else {
      flightSegments = <_FlightSegmentDraft>[
        _FlightSegmentDraft(
          origin: '',
          destination: '',
          flightNumber: '',
          departureAt: DateTime.now().add(const Duration(days: 1, hours: 3)),
          arrivalAt: null,
        ),
      ];
    }
    notesController = TextEditingController(text: entry?.flight.notes ?? '');
    reminders = List<RecruitmentFlightReminder>.from(
      entry?.reminders ?? const <RecruitmentFlightReminder>[],
    );
  }

  @override
  void dispose() {
    for (final segment in flightSegments) {
      segment.dispose();
    }
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

  Future<void> chooseDeparture(int index) async {
    final segment = flightSegments[index];
    final value = await chooseDateTime(segment.departureAt);
    if (value != null && mounted) {
      setState(() => segment.departureAt = value);
    }
  }

  Future<void> chooseArrival(int index) async {
    final segment = flightSegments[index];
    final value = await chooseDateTime(
      segment.arrivalAt ?? segment.departureAt.add(const Duration(hours: 3)),
    );
    if (value != null && mounted) {
      setState(() => segment.arrivalAt = value);
    }
  }

  void addFlightSegment() {
    final previous = flightSegments.last;
    final suggestedDeparture = (previous.arrivalAt ?? previous.departureAt)
        .add(const Duration(hours: 2));
    setState(() {
      flightSegments.add(
        _FlightSegmentDraft(
          origin: previous.destinationController.text.trim(),
          destination: '',
          flightNumber: '',
          departureAt: suggestedDeparture,
          arrivalAt: null,
        ),
      );
    });
  }

  void removeFlightSegment(int index) {
    if (index <= 0 || index >= flightSegments.length) return;
    final removed = flightSegments.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Widget buildFlightSegmentCard(int index) {
    final segment = flightSegments[index];
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  index == 0 ? 'Рейс 1' : 'Рейс ${index + 1} · пересадка',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (index > 0)
                IconButton(
                  tooltip: 'Удалить рейс',
                  onPressed: saving ? null : () => removeFlightSegment(index),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final originField = TextField(
                controller: segment.originController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Откуда',
                  hintText: 'Москва',
                  prefixIcon: Icon(Icons.flight_takeoff_outlined),
                ),
              );
              final destinationField = TextField(
                controller: segment.destinationController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Куда',
                  hintText: 'Мурманск',
                  prefixIcon: Icon(Icons.flight_land_outlined),
                ),
                onChanged: (value) {
                  if (index + 1 < flightSegments.length &&
                      flightSegments[index + 1]
                          .originController
                          .text
                          .trim()
                          .isEmpty) {
                    flightSegments[index + 1].originController.text = value.trim();
                  }
                },
              );
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    originField,
                    const SizedBox(height: 10),
                    destinationField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: originField),
                  const SizedBox(width: 10),
                  Expanded(child: destinationField),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: segment.flightNumberController,
            enabled: !saving,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Номер рейса',
              hintText: 'SU 1320',
              prefixIcon: Icon(Icons.airplane_ticket_outlined),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: saving ? null : () => chooseDeparture(index),
            icon: const Icon(Icons.event_outlined),
            label: Text('Вылет: ${dateTimeText(segment.departureAt)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: saving ? null : () => chooseArrival(index),
            icon: const Icon(Icons.schedule_outlined),
            label: Text(
              segment.arrivalAt == null
                  ? 'Указать время прибытия'
                  : 'Прибытие: ${dateTimeText(segment.arrivalAt!)}',
            ),
          ),
          if (segment.arrivalAt != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: saving
                    ? null
                    : () => setState(() => segment.arrivalAt = null),
                child: const Text('Убрать время прибытия'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> addReminder() async {
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
                const Text(
                  'Событие',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
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
    final tripArrivalAt = flightSegments.last.arrivalAt;
    if (eventKind == 'arrival' && tripArrivalAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала укажите время прибытия последнего рейса')),
      );
      return;
    }

    final now = DateTime.now();
    final eventAt = eventKind == 'arrival'
        ? tripArrivalAt
        : flightSegments.first.departureAt;
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
        const SnackBar(
          content: Text('Выберите будущие дату и время уведомления'),
        ),
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
                ? 'Добавьте дату и время, когда нужно напомнить вам об этом вылете.'
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_outlined,
                      color: AppAdaptivePalette.accentStrong,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
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
        (item) =>
            item.fileName == file.name && item.bytes.length == bytes.length,
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
        if (skippedByLimit > 0) 'не добавлено по лимиту: $skippedByLimit',
        if (rejected > 0) 'пропущено по размеру: $rejected',
      ];
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(details.join(' · '))));
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
    final segmentValues = flightSegments
        .map((segment) => segment.toSegment())
        .toList(growable: false);
    final firstSegment = segmentValues.first;
    final lastSegment = segmentValues.last;
    setState(() => saving = true);
    try {
      await RecruitmentFlightRepository.saveFlight(
        flightId: widget.entry?.flight.id ?? '',
        candidate: selectedCandidate,
        departureAt: firstSegment.departureAt,
        arrivalAt: lastSegment.arrivalAt,
        origin: firstSegment.origin,
        destination: lastSegment.destination,
        flightNumber: firstSegment.flightNumber,
        segments: segmentValues,
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
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
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
          for (var index = 0; index < flightSegments.length; index++) ...[
            buildFlightSegmentCard(index),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: saving ? null : addFlightSegment,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить рейс'),
          ),
          const SizedBox(height: 12),
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
