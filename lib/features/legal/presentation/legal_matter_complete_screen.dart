import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_process_repository.dart';
import '../models/legal_models.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalMatterCompleteScreen extends StatefulWidget {
  final LegalMatter matter;

  const LegalMatterCompleteScreen({super.key, required this.matter});

  @override
  State<LegalMatterCompleteScreen> createState() =>
      _LegalMatterCompleteScreenState();
}

class _LegalMatterCompleteScreenState extends State<LegalMatterCompleteScreen> {
  late Future<_MatterProcessData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_MatterProcessData> load() async {
    final values = await Future.wait<dynamic>([
      LegalProcessRepository.fetchDetails(widget.matter.id),
      LegalOperationsRepository.fetchProcessEvents(widget.matter.id),
    ]);
    return _MatterProcessData(
      process: values[0] as LegalMatterProcessDetails,
      events: values[1] as List<LegalProcessEvent>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String dateTimeText(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date • $time';
  }

  String money(double? value) {
    if (value == null) return '—';
    final raw = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
      buffer.write(raw[index]);
    }
    return '${buffer.toString()} ₽';
  }

  String kindTitle(String kind) => switch (kind) {
    'hearing' => 'Судебное заседание',
    'deadline' => 'Процессуальный срок',
    'filing' => 'Подача документа',
    'incoming' => 'Входящий документ',
    'outgoing' => 'Исходящий документ',
    'decision' => 'Решение',
    'enforcement' => 'Исполнение',
    _ => 'Событие дела',
  };

  IconData kindIcon(String kind) => switch (kind) {
    'hearing' => Icons.account_balance_outlined,
    'deadline' => Icons.timer_outlined,
    'filing' => Icons.upload_file_outlined,
    'incoming' => Icons.mark_email_unread_outlined,
    'outgoing' => Icons.outgoing_mail,
    'decision' => Icons.verified_outlined,
    'enforcement' => Icons.playlist_add_check_circle_outlined,
    _ => Icons.event_note_outlined,
  };

  Widget line(String label, String value) {
    if (value.trim().isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> openFullCard() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: widget.matter, canDecide: false),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> addEvent() async {
    String kind = legalMatterIsCourt(widget.matter) ? 'hearing' : 'outgoing';
    final titleController = TextEditingController();
    DateTime? selectedDate = DateTime.now();

    final draft = await showDialog<_MatterEventDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Событие процесса'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Тип события'),
                  items: const [
                    DropdownMenuItem(
                      value: 'hearing',
                      child: Text('Судебное заседание'),
                    ),
                    DropdownMenuItem(
                      value: 'deadline',
                      child: Text('Процессуальный срок'),
                    ),
                    DropdownMenuItem(
                      value: 'filing',
                      child: Text('Подача документа'),
                    ),
                    DropdownMenuItem(
                      value: 'incoming',
                      child: Text('Входящий документ'),
                    ),
                    DropdownMenuItem(
                      value: 'outgoing',
                      child: Text('Исходящий документ'),
                    ),
                    DropdownMenuItem(value: 'decision', child: Text('Решение')),
                    DropdownMenuItem(
                      value: 'enforcement',
                      child: Text('Исполнение'),
                    ),
                    DropdownMenuItem(value: 'note', child: Text('Другое')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => kind = value ?? 'note');
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Дата'),
                  subtitle: Text(dateTimeText(selectedDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _MatterEventDraft(
                    kind: kind,
                    title: title,
                    date: selectedDate,
                  ),
                );
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (draft == null) return;

    await LegalOperationsRepository.saveProcessEvent(
      matterId: widget.matter.id,
      kind: draft.kind,
      title: draft.title,
      eventAt: draft.kind == 'deadline' ? null : draft.date,
      dueAt: draft.kind == 'deadline' ? draft.date : null,
    );
    if (mounted) await refresh();
  }

  Future<void> eventAction(LegalProcessEvent item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Выполнено'),
              onTap: () => Navigator.pop(context, 'completed'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Отменить событие'),
              onTap: () => Navigator.pop(context, 'cancelled'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    if (action == 'delete') {
      await LegalOperationsRepository.deleteProcessEvent(item.id);
    } else {
      await LegalOperationsRepository.saveProcessEvent(
        id: item.id,
        matterId: widget.matter.id,
        kind: item.kind,
        title: item.title,
        eventAt: item.eventAt,
        dueAt: item.dueAt,
        status: action,
        result: item.result,
      );
    }
    if (mounted) await refresh();
  }

  Widget processSummary(LegalMatterProcessDetails process) {
    if (!legalMatterIsCourt(widget.matter) &&
        widget.matter.matterType != LegalMatterType.claim) {
      return const SizedBox.shrink();
    }
    final court = legalMatterIsCourt(widget.matter);
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            court ? 'Судебное производство' : 'Претензионная работа',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (court) line('Номер дела', process.courtCaseNumber),
          if (court) line('Суд', process.courtName),
          if (court) line('Стороны', process.courtParties),
          line('Сумма требований', money(process.claimAmount)),
          line('Стадия', process.proceedingStage),
          if (court)
            line('Ближайшее заседание', dateTimeText(process.nextHearingAt)),
          if (!court)
            line('Претензия отправлена', dateTimeText(process.outgoingSentAt)),
          line(
            court ? 'Процессуальный срок' : 'Ответ до',
            dateTimeText(process.responseDueAt),
          ),
          if (process.isResponseOverdue)
            const Text(
              'Срок просрочен',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }

  Widget timeline(List<LegalProcessEvent> events) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Процессуальная лента',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: addEvent,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Событие'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Text(
              'Добавьте заседание, срок, подачу документа, решение или исполнение.',
            )
          else
            ...events.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Icon(kindIcon(item.kind))),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    kindTitle(item.kind),
                    if (item.eventAt != null) dateTimeText(item.eventAt),
                    if (item.dueAt != null) 'срок ${dateTimeText(item.dueAt)}',
                    if (item.status == 'completed') 'выполнено',
                    if (item.status == 'cancelled') 'отменено',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.more_horiz_rounded),
                onTap: () => eventAction(item),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courtOrClaim =
        legalMatterIsCourt(widget.matter) ||
        widget.matter.matterType == LegalMatterType.claim;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Юридическое дело'),
        actions: [
          IconButton(
            tooltip: 'Полная карточка',
            onPressed: openFullCard,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_MatterProcessData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Не удалось загрузить дело: ${snapshot.error}'),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return AppPage(
            title: widget.matter.title,
            subtitle:
                '${legalMatterDisplayType(widget.matter)} • ${widget.matter.statusTitle} • ${widget.matter.riskTitle} риск',
            headerTrailing: FilledButton.icon(
              onPressed: openFullCard,
              icon: const Icon(Icons.article_outlined),
              label: const Text('Карточка дела'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                processSummary(data.process),
                if (courtOrClaim) ...[
                  const SizedBox(height: 12),
                  timeline(data.events),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatterEventDraft {
  final String kind;
  final String title;
  final DateTime? date;

  const _MatterEventDraft({
    required this.kind,
    required this.title,
    required this.date,
  });
}

class _MatterProcessData {
  final LegalMatterProcessDetails process;
  final List<LegalProcessEvent> events;

  const _MatterProcessData({required this.process, required this.events});
}
