part of 'legal_matters_screen.dart';

class LegalMatterDetailsScreen extends StatefulWidget {
  final LegalMatter matter;
  final bool canDecide;

  const LegalMatterDetailsScreen({
    super.key,
    required this.matter,
    this.canDecide = false,
  });

  @override
  State<LegalMatterDetailsScreen> createState() =>
      _LegalMatterDetailsScreenState();
}

class _LegalMatterDetailsScreenState extends State<LegalMatterDetailsScreen> {
  late LegalMatter matter;
  late Future<_LegalMatterWorkspaceViewData> future;

  bool get canEdit => !widget.canDecide;

  @override
  void initState() {
    super.initState();
    matter = widget.matter;
    future = load();
  }

  Future<_LegalMatterWorkspaceViewData> load() async {
    final values = await Future.wait<dynamic>([
      LegalMatterWorkspaceRepository.fetch(matter.id),
      LegalRepository.fetchDocuments(),
      LegalProcessRepository.fetchDetails(matter.id),
    ]);
    final documents = (values[1] as List<LegalDocument>)
        .where(
          (item) =>
              item.legalMatterId == matter.id ||
              (matter.documentId.isNotEmpty && item.id == matter.documentId),
        )
        .toList(growable: false);
    return _LegalMatterWorkspaceViewData(
      workspace: values[0] as LegalMatterWorkspaceData,
      documents: documents,
      process: values[2] as LegalMatterProcessDetails,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String dateTimeText(DateTime? value) {
    if (value == null) return '—';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${date(value)} • $hour:$minute';
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

  Widget line(String label, String value) {
    if (value.trim().isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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

  Widget title(String value, {String? subtitle, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget card(Widget child) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => LegalMatterEditorScreen(matter: matter),
      ),
    );
    if (saved != true) return;
    final fresh = await LegalRepository.fetchMatter(matter.id);
    if (!mounted) return;
    setState(() => matter = fresh);
    await refresh();
  }

  Future<void> editBasis(String current) async {
    final controller = TextEditingController(text: current);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Основание дела'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'Договор, акт, переписка, событие, норма закона или иное основание',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await LegalMatterWorkspaceRepository.saveBasis(
      matterId: matter.id,
      basis: value,
    );
    if (mounted) await refresh();
  }

  Future<void> addNote() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Запись в историю'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'Звонок, письмо, полученный ответ, договорённость или следующий шаг',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.isEmpty) return;
    await LegalMatterWorkspaceRepository.addNote(
      matterId: matter.id,
      body: value,
    );
    if (mounted) await refresh();
  }

  Future<void> openDocument(LegalDocument document) async {
    final files = await LegalRepository.fetchDocumentFiles(document.id);
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У документа пока нет прикреплённых файлов'),
        ),
      );
      return;
    }
    if (files.length == 1) {
      await LegalRepository.openFile(files.first);
      return;
    }
    final selected = await showDialog<LegalFile>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: files
                .map(
                  (file) => ListTile(
                    leading: const Icon(Icons.attach_file_rounded),
                    title: Text(file.originalName),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => Navigator.pop(context, file),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected != null) await LegalRepository.openFile(selected);
  }

  Future<void> decide(bool approved) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approved ? 'Согласовать решение' : 'Отклонить решение'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Комментарий руководителя',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (comment == null) return;
    await LegalRepository.decideMatter(
      matterId: matter.id,
      approved: approved,
      comment: comment,
    );
    final fresh = await LegalRepository.fetchMatter(matter.id);
    if (!mounted) return;
    setState(() => matter = fresh);
    await refresh();
  }

  Widget overview(LegalMatterWorkspaceData workspace) {
    return card(
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
          const SizedBox(height: 18),
          title('Суть дела'),
          const SizedBox(height: 8),
          Text(
            matter.description.trim().isEmpty
                ? 'Суть дела пока не описана'
                : matter.description,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 18),
          title(
            'Основание',
            subtitle:
                'Факт, документ или правовое основание, на котором строится работа',
            trailing: canEdit
                ? IconButton(
                    tooltip: 'Изменить основание',
                    onPressed: () => editBasis(workspace.basis),
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            workspace.basis.trim().isEmpty
                ? 'Основание пока не указано'
                : workspace.basis,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget processCard(LegalMatterProcessDetails process) {
    if (!legalMatterIsCourt(matter) &&
        matter.matterType != LegalMatterType.claim) {
      return const SizedBox.shrink();
    }
    final court = legalMatterIsCourt(matter);
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(court ? 'Судебное производство' : 'Претензионная работа'),
          const SizedBox(height: 14),
          if (court) ...[
            line('Номер дела', process.courtCaseNumber),
            line('Суд', process.courtName),
            line('Стороны', process.courtParties),
          ],
          line(
            'Сумма требований',
            process.claimAmount == null ? '—' : money(process.claimAmount),
          ),
          line('Стадия', process.proceedingStage),
          if (court) line('Заседание', dateTimeText(process.nextHearingAt)),
          if (!court) line('Отправлено', date(process.outgoingSentAt)),
          line(
            court ? 'Процессуальный срок' : 'Ответ до',
            date(process.responseDueAt),
          ),
          if (process.isResponseOverdue)
            const Text(
              'Срок ответа/действия просрочен',
              style: TextStyle(
                color: Color(0xFFB5483F),
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }

  Widget participants() {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title('Участники и ответственность'),
          const SizedBox(height: 14),
          line('Ответственный', matter.responsibleName),
          line('Сотрудник', matter.employeeName),
          line('Объект', matter.objectName),
          line('Контрагент', matter.counterpartyName),
          if (matter.responsibleName.isEmpty &&
              matter.employeeName.isEmpty &&
              matter.objectName.isEmpty &&
              matter.counterpartyName.isEmpty)
            Text(
              'Связи пока не указаны',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            ),
        ],
      ),
    );
  }

  Widget control() {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title('Контроль дела'),
          const SizedBox(height: 14),
          line('Срок', date(matter.dueAt)),
          line('Что сделать', matter.requiredActions),
          line('Результат', matter.result),
          line('Вопрос руководителю', matter.managerQuestion),
          line('Решение', matter.decisionComment),
          if (matter.requiresForemanAction)
            line('Прораб', 'Требуется действие прораба'),
        ],
      ),
    );
  }

  Widget documents(List<LegalDocument> documents) {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(
            'Связанные документы',
            subtitle: 'Все документы, привязанные к этому делу',
          ),
          const SizedBox(height: 10),
          if (documents.isEmpty)
            Text(
              'Связанных документов пока нет',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            )
          else
            ...documents.map(
              (document) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.description_outlined),
                ),
                title: Text(
                  document.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    if (document.documentType.isNotEmpty) document.documentType,
                    document.statusTitle,
                    if (document.documentNumber.isNotEmpty)
                      '№ ${document.documentNumber}',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => openDocument(document),
              ),
            ),
        ],
      ),
    );
  }

  IconData historyIcon(String type) => switch (type) {
    'created' => Icons.add_circle_outline_rounded,
    'status' => Icons.flag_outlined,
    'decision' => Icons.how_to_reg_outlined,
    'note' => Icons.chat_bubble_outline_rounded,
    _ => Icons.edit_note_rounded,
  };

  Widget history(LegalMatterWorkspaceData workspace) {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(
            'История дела',
            subtitle: 'Изменения, решения, звонки, письма и договорённости',
            trailing: canEdit
                ? FilledButton.icon(
                    onPressed: addNote,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Запись'),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          if (workspace.events.isEmpty)
            Text(
              'История пока пуста',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            )
          else
            ...workspace.events.map((event) {
              final actor = workspace.actorName(event.actorUserId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      child: Icon(historyIcon(event.eventType), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title.isEmpty ? 'Событие' : event.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          if (event.body.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(event.body),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            <String>[
                              dateTimeText(event.createdAt),
                              if (actor.isNotEmpty) actor,
                            ].join(' • '),
                            style: TextStyle(
                              color: AppAdaptivePalette.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Юридическое дело'),
        actions: [
          if (canEdit)
            IconButton(
              onPressed: edit,
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AppPage(
        title: matter.title,
        subtitle:
            '${legalMatterDisplayType(matter)} • ${matter.riskTitle} риск • ${matter.statusTitle}',
        child: FutureBuilder<_LegalMatterWorkspaceViewData>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return card(
                  Text('Не удалось загрузить карточку: ${snapshot.error}'),
                );
              }
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final data = snapshot.data!;
            return Column(
              children: [
                overview(data.workspace),
                if (legalMatterIsCourt(matter) ||
                    matter.matterType == LegalMatterType.claim) ...[
                  const SizedBox(height: 12),
                  processCard(data.process),
                ],
                const SizedBox(height: 12),
                participants(),
                const SizedBox(height: 12),
                control(),
                const SizedBox(height: 12),
                documents(data.documents),
                const SizedBox(height: 12),
                history(data.workspace),
                if (widget.canDecide && matter.needsManager) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => decide(false),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Отклонить'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => decide(true),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Согласовать'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LegalMatterWorkspaceViewData {
  final LegalMatterWorkspaceData workspace;
  final List<LegalDocument> documents;
  final LegalMatterProcessDetails process;

  const _LegalMatterWorkspaceViewData({
    required this.workspace,
    required this.documents,
    required this.process,
  });
}
