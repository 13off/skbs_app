import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_matter_workspace_repository.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_process_repository.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_document_complete_screen.dart';
import 'legal_matters_screen.dart';

class LegalMatterCompleteScreen extends StatefulWidget {
  final LegalMatter matter;

  const LegalMatterCompleteScreen({super.key, required this.matter});

  @override
  State<LegalMatterCompleteScreen> createState() =>
      _LegalMatterCompleteScreenState();
}

class _LegalMatterCompleteScreenState extends State<LegalMatterCompleteScreen> {
  late LegalMatter matter;
  late Future<_MatterCompleteData> future;

  @override
  void initState() {
    super.initState();
    matter = widget.matter;
    future = load();
  }

  Future<_MatterCompleteData> load() async {
    final values = await Future.wait<dynamic>([
      LegalMatterWorkspaceRepository.fetch(matter.id),
      LegalProcessRepository.fetchDetails(matter.id),
      LegalOperationsRepository.fetchProcessEvents(matter.id),
      LegalRepository.fetchDocuments(),
    ]);
    return _MatterCompleteData(
      workspace: values[0] as LegalMatterWorkspaceData,
      process: values[1] as LegalMatterProcessDetails,
      processEvents: values[2] as List<LegalProcessEvent>,
      documents: (values[3] as List<LegalDocument>)
          .where(
            (item) =>
                item.legalMatterId == matter.id ||
                (matter.documentId.isNotEmpty && item.id == matter.documentId),
          )
          .toList(),
    );
  }

  Future<void> refresh() async {
    final fresh = await LegalRepository.fetchMatter(matter.id);
    final next = load();
    if (!mounted) return;
    setState(() {
      matter = fresh;
      future = next;
    });
    await next;
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String dateTimeText(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${date(local)} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String money(double? value) {
    if (value == null) return '—';
    final raw = value.round().toString();
    final out = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) out.write(' ');
      out.write(raw[i]);
    }
    return '${out.toString()} ₽';
  }

  Widget card(String title, Widget child, {Widget? trailing, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 24,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 145, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Future<void> editMatter() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => LegalMatterEditorScreen(matter: matter),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> editBasis(String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Основание дела'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: 'Договор, акт, переписка, событие или правовое основание',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await LegalMatterWorkspaceRepository.saveBasis(matterId: matter.id, basis: value);
    if (mounted) await refresh();
  }

  Future<void> addHistoryNote() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Запись в историю'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 7,
          decoration: const InputDecoration(
            hintText: 'Звонок, письмо, договорённость, ответ или следующий шаг',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await LegalMatterWorkspaceRepository.addNote(matterId: matter.id, body: value);
    if (mounted) await refresh();
  }

  String kindTitle(String kind) => switch (kind) {
        'hearing' => 'Судебное заседание',
        'deadline' => 'Процессуальный срок',
        'filing' => 'Подача документа',
        'incoming' => 'Входящий документ',
        'outgoing' => 'Исходящий документ',
        'decision' => 'Решение',
        'enforcement' => 'Исполнение',
        _ => 'Событие',
      };

  Future<void> addProcessEvent() async {
    String kind = legalMatterIsCourt(matter) ? 'hearing' : 'outgoing';
    final titleController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    final result = await showDialog<_ProcessEventDraft>(
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
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'hearing', child: Text('Судебное заседание')),
                    DropdownMenuItem(value: 'deadline', child: Text('Процессуальный срок')),
                    DropdownMenuItem(value: 'filing', child: Text('Подача документа')),
                    DropdownMenuItem(value: 'incoming', child: Text('Входящий документ')),
                    DropdownMenuItem(value: 'outgoing', child: Text('Исходящий документ')),
                    DropdownMenuItem(value: 'decision', child: Text('Решение')),
                    DropdownMenuItem(value: 'enforcement', child: Text('Исполнение')),
                    DropdownMenuItem(value: 'note', child: Text('Другое')),
                  ],
                  onChanged: (value) => setDialogState(() => kind = value ?? 'note'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Дата'),
                  subtitle: Text(date(selectedDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  _ProcessEventDraft(kind: kind, title: title, date: selectedDate),
                );
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (result == null) return;
    await LegalOperationsRepository.saveProcessEvent(
      matterId: matter.id,
      kind: result.kind,
      title: result.title,
      eventAt: result.kind == 'deadline' ? null : result.date,
      dueAt: result.kind == 'deadline' ? result.date : null,
    );
    if (mounted) await refresh();
  }

  Future<void> updateProcessEvent(LegalProcessEvent item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Отметить выполненным'),
              onTap: () => Navigator.pop(context, 'complete'),
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Отменить событие'),
              onTap: () => Navigator.pop(context, 'cancel'),
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
    if (action == 'delete') {
      await LegalOperationsRepository.deleteProcessEvent(item.id);
    } else if (action == 'complete' || action == 'cancel') {
      await LegalOperationsRepository.saveProcessEvent(
        id: item.id,
        matterId: matter.id,
        kind: item.kind,
        title: item.title,
        eventAt: item.eventAt,
        dueAt: item.dueAt,
        status: action == 'complete' ? 'completed' : 'cancelled',
        result: item.result,
      );
    }
    if (mounted && action != null) await refresh();
  }

  Widget overview(LegalMatterWorkspaceData workspace) {
    return card(
      'Карточка дела',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(legalMatterDisplayType(matter))),
              Chip(label: Text(matter.statusTitle)),
              Chip(label: Text('${matter.riskTitle} риск')),
              if (matter.isOverdue) const Chip(label: Text('Срок просрочен')),
            ],
          ),
          const SizedBox(height: 12),
          line('Суть', matter.description),
          line('Основание', workspace.basis),
          line('Ответственный', matter.responsibleName),
          line('Сотрудник', matter.employeeName),
          line('Объект', matter.objectName),
          line('Контрагент', matter.counterpartyName),
          line('Срок', dateTimeText(matter.dueAt)),
          line('Что сделать', matter.requiredActions),
          line('Результат', matter.result),
          line('Вопрос руководителю', matter.managerQuestion),
          line('Решение руководителя', matter.decisionComment),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') editMatter();
          if (value == 'basis') editBasis(workspace.basis);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Редактировать дело')),
          PopupMenuItem(value: 'basis', child: Text('Изменить основание')),
        ],
      ),
    );
  }

  Widget processDetails(LegalMatterProcessDetails process) {
    if (!legalMatterIsCourt(matter) && matter.matterType != LegalMatterType.claim) {
      return const SizedBox.shrink();
    }
    final court = legalMatterIsCourt(matter);
    return card(
      court ? 'Судебное производство' : 'Претензионная работа',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (court) line('Номер дела', process.courtCaseNumber),
          if (court) line('Суд', process.courtName),
          if (court) line('Стороны', process.courtParties),
          line('Сумма требований', money(process.claimAmount)),
          line('Стадия', process.proceedingStage),
          if (court) line('Ближайшее заседание', dateTimeText(process.nextHearingAt)),
          if (!court) line('Претензия отправлена', dateTimeText(process.outgoingSentAt)),
          line(court ? 'Процессуальный срок' : 'Ответ до', dateTimeText(process.responseDueAt)),
          if (process.isResponseOverdue)
            const Text(
              'Срок просрочен',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
        ],
      ),
    );
  }

  Widget timeline(List<LegalProcessEvent> items) {
    return card(
      'Процессуальная лента',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            const Text('Событий пока нет. Добавьте заседание, срок, отправку или решение.')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    item.kind == 'hearing'
                        ? Icons.account_balance_outlined
                        : item.kind == 'deadline'
                            ? Icons.timer_outlined
                            : item.kind == 'decision'
                                ? Icons.verified_outlined
                                : Icons.event_note_outlined,
                  ),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
                onTap: () => updateProcessEvent(item),
              ),
            ),
        ],
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: addProcessEvent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Событие'),
      ),
      subtitle: 'Заседания, сроки, документы, решения и исполнение',
    );
  }

  Widget documents(List<LegalDocument> items) {
    return card(
      'Связанные документы',
      Column(
        children: [
          if (items.isEmpty)
            const Align(alignment: Alignment.centerLeft, child: Text('Связанных документов пока нет'))
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.description_outlined)),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${item.documentType} • ${item.statusTitle}'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => LegalDocumentCompleteScreen(document: item),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget history(LegalMatterWorkspaceData workspace) {
    return card(
      'История дела',
      Column(
        children: [
          if (workspace.events.isEmpty)
            const Align(alignment: Alignment.centerLeft, child: Text('История пока пуста'))
          else
            ...workspace.events.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  <String>[
                    if (item.body.isNotEmpty) item.body,
                    dateTimeText(item.createdAt),
                    if (workspace.actorName(item.actorUserId).isNotEmpty)
                      workspace.actorName(item.actorUserId),
                  ].join(' • '),
                ),
              ),
            ),
        ],
      ),
      trailing: FilledButton.tonalIcon(
        onPressed: addHistoryNote,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Запись'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Юридическое дело'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_MatterCompleteData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Не удалось загрузить дело: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return AppPage(
            title: matter.title,
            subtitle: '${legalMatterDisplayType(matter)} • ${matter.statusTitle}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                overview(data.workspace),
                processDetails(data.process),
                if (legalMatterIsCourt(matter) || matter.matterType == LegalMatterType.claim)
                  timeline(data.processEvents),
                documents(data.documents),
                history(data.workspace),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProcessEventDraft {
  final String kind;
  final String title;
  final DateTime? date;

  const _ProcessEventDraft({required this.kind, required this.title, required this.date});
}

class _MatterCompleteData {
  final LegalMatterWorkspaceData workspace;
  final LegalMatterProcessDetails process;
  final List<LegalProcessEvent> processEvents;
  final List<LegalDocument> documents;

  const _MatterCompleteData({
    required this.workspace,
    required this.process,
    required this.processEvents,
    required this.documents,
  });
}
