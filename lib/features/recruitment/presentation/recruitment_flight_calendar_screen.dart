import 'dart:typed_data';

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

  Future<void> openTicket(RecruitmentFlight flight) async {
    try {
      final url = await RecruitmentFlightRepository.createTicketUrl(flight);
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
                    PopupMenuItem(value: 'checked_in', child: Text('Регистрация пройдена')),
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
                  icon: flight.hasTicket
                      ? Icons.attachment_rounded
                      : Icons.warning_amber_rounded,
                  text: flight.hasTicket ? 'Билет прикреплён' : 'Нет билета',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: flight.hasTicket ? () => openTicket(flight) : null,
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text('Билет'),
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
          final data = snapshot.data ??
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
                    'После сохранения билета вылет появляется в календаре. Система создаёт напоминания за сутки и за 3 часа, а HR может отправить напоминание вручную.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: data.candidates.isEmpty
                    ? null
                    : () => openEditor(data),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить вылет и билет'),
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
  late bool remindDayBefore;
  late bool remindThreeHours;
  Uint8List? ticketBytes;
  String ticketFileName = '';
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    candidate = entry?.candidate;
    departureAt = entry?.flight.departureAt ??
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
    remindDayBefore = entry?.flight.remindDayBefore ?? true;
    remindThreeHours = entry?.flight.remindThreeHours ?? true;
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

  Future<void> chooseTicket() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'Билет',
          extensions: <String>['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
        ),
      ],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 20 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл билета должен быть меньше 20 МБ')),
      );
      return;
    }
    setState(() {
      ticketBytes = bytes;
      ticketFileName = file.name;
    });
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
        remindDayBefore: remindDayBefore,
        remindThreeHours: remindThreeHours,
        notes: notesController.text,
        ticketBytes: ticketBytes,
        ticketFileName: ticketFileName,
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
    final existingTicket = widget.entry?.flight.ticketOriginalName ?? '';
    final displayedTicket = ticketFileName.isNotEmpty
        ? ticketFileName
        : existingTicket;
    return AppPage(
      title: widget.entry == null ? 'Новый вылет' : 'Изменить вылет',
      subtitle: 'Точный маршрут, время и купленный билет',
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
            onChanged: saving ? null : (value) => setState(() => candidate = value),
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
                onPressed: saving ? null : () => setState(() => arrivalAt = null),
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
                  'Купленный билет',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  displayedTicket.isEmpty
                      ? 'Прикрепи PDF или фотографию билета. Без файла вылет не сохранится.'
                      : displayedTicket,
                  style: TextStyle(
                    color: displayedTicket.isEmpty
                        ? AppAdaptivePalette.textMuted
                        : AppAdaptivePalette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: saving ? null : chooseTicket,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(
                    displayedTicket.isEmpty ? 'Прикрепить билет' : 'Заменить билет',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
            subtitle: const Text('Повторное напоминание перед поездкой в аэропорт.'),
          ),
          const SizedBox(height: 8),
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
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
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
