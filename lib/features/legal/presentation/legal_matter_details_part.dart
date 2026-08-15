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
  late Future<_LegalMatterWorkspaceViewData> workspaceFuture;

  bool get canEdit => !widget.canDecide;

  @override
  void initState() {
    super.initState();
    matter = widget.matter;
    workspaceFuture = loadWorkspace();
  }

  Future<_LegalMatterWorkspaceViewData> loadWorkspace() async {
    final values = await Future.wait<dynamic>([
      LegalMatterWorkspaceRepository.fetch(matter.id),
      LegalRepository.fetchDocuments(),
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
    );
  }

  Future<void> refreshWorkspace() async {
    final next = loadWorkspace();
    setState(() => workspaceFuture = next);
    await next;
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String dateTimeText(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year} • $hour:$minute';
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
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

  Widget sectionTitle(String title, {String? subtitle, Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
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

  Widget badge(String text, IconData icon, {bool danger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: danger
            ? const Color(0xFFF4E9E7)
            : AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => LegalMatterEditorScreen(matter: matter),
      ),
    );
    if (saved != true) return;
    final fresh = await LegalRepository.fetchMatter(matter.id);
    if (!mounted) return;
    setState(() => matter = fresh);
    await refreshWorkspace();
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
                  'Договор, акт, пункт, переписка, событие или иное основание',
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
    try {
      await LegalMatterWorkspaceRepository.saveBasis(
        matterId: matter.id,
        basis: value,
      );
      if (mounted) await refreshWorkspace();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить основание: $error')),
      );
    }
  }

  Future<void> addNote() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить запись в историю'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText:
                  'Звонок, письмо, договорённость, полученный ответ или следующий шаг',
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
    try {
      await LegalMatterWorkspaceRepository.addNote(
        matterId: matter.id,
        body: value,
      );
      if (mounted) await refreshWorkspace();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить запись: $error')),
      );
    }
  }

  Future<void> openRelatedDocument(LegalDocument document) async {
    try {
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть документ: $error')),
      );
    }
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
    await refreshWorkspace();
  }

  Widget overviewCard(LegalMatterWorkspaceData workspace) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              badge(matter.typeTitle, Icons.work_outline_rounded),
              badge(matter.statusTitle, Icons.flag_outlined),
              badge(
                '${matter.riskTitle} риск',
                matter.isHighRisk
                    ? Icons.warning_amber_rounded
                    : Icons.shield_outlined,
                danger: matter.isHighRisk,
              ),
              if (matter.isOverdue)
                badge(
                  'Срок просрочен',
                  Icons.timer_off_outlined,
                  danger: true,
                ),
            ],
          ),
          const SizedBox(height: 18),
          sectionTitle('Суть дела'),
          const SizedBox(height: 10),
          Text(
            matter.description.trim().isEmpty
                ? 'Описание пока не заполнено'
                : matter.description,
            style: TextStyle(
              color: matter.description.trim().isEmpty
                  ? AppAdaptivePalette.textMuted
                  : AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          sectionTitle(
            'Основание',
            subtitle: 'На каком документе, факте или событии строится позиция',
            trailing: canEdit
                ? IconButton(
                    onPressed: () => editBasis(workspace.basis),
                    tooltip: 'Изменить основание',
                    icon: const Icon(Icons.edit_outlined),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            workspace.basis.trim().isEmpty
                ? 'Основание пока не указано'
                : workspace.basis,
            style: TextStyle(
              color: workspace.basis.trim().isEmpty
                  ? AppAdaptivePalette.textMuted
                  : AppAdaptivePalette.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget participantsCard() {
    final hasParticipants = matter.employeeName.isNotEmpty ||
        matter.objectName.isNotEmpty ||
        matter.counterpartyName.isNotEmpty ||
        matter.responsibleName.isNotEmpty;
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'Участники и ответственность',
            subtitle: 'Кого касается дело и кто ведёт его внутри компании',
          ),
          const SizedBox(height: 14),
          if (!hasParticipants)
            Text(
              'Связи пока не указаны',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            )
          else ...[
            line('Ответственный', matter.responsibleName),
            line('Сотрудник', matter.employeeName),
            line('Объект', matter.objectName),
            line('Контрагент', matter.counterpartyName),
          ],
        ],
      ),
    );
  }

  Widget controlCard() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'Контроль дела',
            subtitle: 'Срок, необходимые действия, решение и результат',
          ),
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

  Widget documentsCard(List<LegalDocument> documents) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
            'Связанные документы',
            subtitle: 'Договоры, акты, претензии и другие материалы этого дела',
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
                onTap: () => openRelatedDocument(document),
              ),
            ),
        ],
      ),
    );
  }

  IconData eventIcon(String type) => switch (type) {
        'created' => Icons.add_circle_outline_rounded,
        'status' => Icons.flag_outlined,
        'decision' => Icons.how_to_reg_outlined,
        'note' => Icons.chat_bubble_outline_rounded,
        _ => Icons.edit_note_rounded,
      };

  Widget historyCard(LegalMatterWorkspaceData workspace) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle(
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppAdaptivePalette.surfaceSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(eventIcon(event.eventType), size: 19),
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
                              fontWeight: FontWeight.w600,
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
              tooltip: 'Редактировать дело',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: AppPage(
        title: matter.title,
        subtitle:
            '${matter.typeTitle} • ${matter.riskTitle} риск • ${matter.statusTitle}',
        child: FutureBuilder<_LegalMatterWorkspaceViewData>(
          future: workspaceFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return PremiumWorkCard(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(
                      'Не удалось загрузить карточку: ${snapshot.error}',
                    ),
                  ),
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
                overviewCard(data.workspace),
                const SizedBox(height: 12),
                participantsCard(),
                const SizedBox(height: 12),
                controlCard(),
                const SizedBox(height: 12),
                documentsCard(data.documents),
                const SizedBox(height: 12),
                historyCard(data.workspace),
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

  const _LegalMatterWorkspaceViewData({
    required this.workspace,
    required this.documents,
  });
}
