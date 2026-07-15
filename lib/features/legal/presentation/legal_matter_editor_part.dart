part of 'legal_matters_screen.dart';

class LegalMatterEditorScreen extends StatefulWidget {
  final LegalMatter? matter;

  const LegalMatterEditorScreen({super.key, this.matter});

  @override
  State<LegalMatterEditorScreen> createState() => _LegalMatterEditorScreenState();
}

class _LegalMatterEditorScreenState extends State<LegalMatterEditorScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final actionsController = TextEditingController();
  final resultController = TextEditingController();
  final managerQuestionController = TextEditingController();
  String type = LegalMatterType.task;
  String risk = LegalRiskLevel.medium;
  String status = LegalMatterStatus.open;
  DateTime? dueAt;
  String? employeeId;
  String? objectId;
  String? counterpartyId;
  String? documentId;
  String? responsibleId;
  bool foremanAction = false;
  bool managerDecision = false;
  bool saving = false;
  late Future<_MatterDirectories> directoriesFuture;

  @override
  void initState() {
    super.initState();
    final item = widget.matter;
    if (item != null) {
      titleController.text = item.title;
      descriptionController.text = item.description;
      actionsController.text = item.requiredActions;
      resultController.text = item.result;
      managerQuestionController.text = item.managerQuestion;
      type = item.matterType;
      risk = item.riskLevel;
      status = item.status;
      dueAt = item.dueAt;
      employeeId = item.employeeId.isEmpty ? null : item.employeeId;
      objectId = item.objectId.isEmpty ? null : item.objectId;
      counterpartyId = item.counterpartyId.isEmpty ? null : item.counterpartyId;
      documentId = item.documentId.isEmpty ? null : item.documentId;
      responsibleId = item.responsibleUserId.isEmpty ? null : item.responsibleUserId;
      foremanAction = item.requiresForemanAction;
      managerDecision = item.requiresManagerDecision;
    }
    directoriesFuture = loadDirectories();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    actionsController.dispose();
    resultController.dispose();
    managerQuestionController.dispose();
    super.dispose();
  }

  Future<_MatterDirectories> loadDirectories() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchEmployeeDirectory(),
      LegalRepository.fetchObjectDirectory(),
      LegalRepository.fetchCounterparties(),
      LegalRepository.fetchResponsibleDirectory(),
      LegalRepository.fetchDocuments(),
    ]);
    return _MatterDirectories(
      employees: values[0] as List<LegalDirectoryItem>,
      objects: values[1] as List<LegalDirectoryItem>,
      counterparties: values[2] as List<LegalCounterparty>,
      responsible: values[3] as List<LegalDirectoryItem>,
      documents: values[4] as List<LegalDocument>,
    );
  }

  DropdownMenuItem<String> directoryItem(LegalDirectoryItem item) {
    return DropdownMenuItem(value: item.id, child: Text(item.title, overflow: TextOverflow.ellipsis));
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Не указан';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<void> save() async {
    if (saving) return;
    if (titleController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите название вопроса')));
      return;
    }
    setState(() => saving = true);
    try {
      await LegalRepository.saveMatter(
        id: widget.matter?.id,
        matterType: type,
        title: titleController.text,
        description: descriptionController.text,
        riskLevel: risk,
        status: status,
        dueAt: dueAt,
        responsibleUserId: responsibleId,
        employeeId: employeeId,
        objectId: objectId,
        counterpartyId: counterpartyId,
        documentId: documentId,
        requiredActions: actionsController.text,
        result: resultController.text,
        requiresForemanAction: foremanAction,
        requiresManagerDecision: managerDecision,
        managerQuestion: managerQuestionController.text,
        decisionStatus: widget.matter?.decisionStatus ?? 'none',
        decisionComment: widget.matter?.decisionComment ?? '',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.matter == null ? 'Новый вопрос' : 'Редактировать вопрос')),
      body: AppPage(
        title: widget.matter == null ? 'Новый вопрос' : 'Юридический вопрос',
        subtitle: 'Риск, ответственный, срок и необходимые действия',
        child: FutureBuilder<_MatterDirectories>(
          future: directoriesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
              return const PremiumWorkCard(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())));
            }
            final data = snapshot.data!;
            return Column(
              children: [
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название')),
                      const SizedBox(height: 12),
                      TextField(controller: descriptionController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Описание', alignLabelWithHint: true)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Тип вопроса'),
                        items: LegalMatterType.values.map((value) => DropdownMenuItem(value: value, child: Text(LegalMatterType.title(value)))).toList(),
                        onChanged: saving ? null : (value) => setState(() => type = value ?? LegalMatterType.task),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: risk,
                        decoration: const InputDecoration(labelText: 'Уровень риска'),
                        items: LegalRiskLevel.values.map((value) => DropdownMenuItem(value: value, child: Text(LegalRiskLevel.title(value)))).toList(),
                        onChanged: saving ? null : (value) => setState(() => risk = value ?? LegalRiskLevel.medium),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Статус'),
                        items: LegalMatterStatus.values.map((value) => DropdownMenuItem(value: value, child: Text(LegalMatterStatus.title(value)))).toList(),
                        onChanged: saving ? null : (value) => setState(() => status = value ?? LegalMatterStatus.open),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Срок'),
                        subtitle: Text(dateText(dueAt)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final value = await showDatePicker(
                            context: context,
                            initialDate: dueAt ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (value != null) setState(() => dueAt = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: data.responsible.any((item) => item.id == responsibleId) ? responsibleId : null,
                        decoration: const InputDecoration(labelText: 'Ответственный'),
                        items: data.responsible.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => responsibleId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.employees.any((item) => item.id == employeeId) ? employeeId : null,
                        decoration: const InputDecoration(labelText: 'Сотрудник'),
                        items: data.employees.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => employeeId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.objects.any((item) => item.id == objectId) ? objectId : null,
                        decoration: const InputDecoration(labelText: 'Объект'),
                        items: data.objects.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => objectId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.counterparties.any((item) => item.id == counterpartyId) ? counterpartyId : null,
                        decoration: const InputDecoration(labelText: 'Контрагент'),
                        items: data.counterparties.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: saving ? null : (value) => setState(() => counterpartyId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.documents.any((item) => item.id == documentId) ? documentId : null,
                        decoration: const InputDecoration(labelText: 'Связанный документ'),
                        items: data.documents.map((item) => DropdownMenuItem(value: item.id, child: Text(item.title, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: saving ? null : (value) => setState(() => documentId = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(controller: actionsController, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Необходимые действия', alignLabelWithHint: true)),
                      const SizedBox(height: 12),
                      TextField(controller: resultController, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Результат', alignLabelWithHint: true)),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Требуется действие прораба'),
                        value: foremanAction,
                        onChanged: saving ? null : (value) => setState(() => foremanAction = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Требуется решение руководителя'),
                        value: managerDecision,
                        onChanged: saving ? null : (value) => setState(() => managerDecision = value),
                      ),
                      if (managerDecision) ...[
                        const SizedBox(height: 8),
                        TextField(controller: managerQuestionController, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Вопрос руководителю', alignLabelWithHint: true)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumActionButton(
                  label: widget.matter == null ? 'Создать вопрос' : 'Сохранить вопрос',
                  icon: Icons.save_outlined,
                  onPressed: saving ? null : save,
                  isLoading: saving,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MatterDirectories {
  final List<LegalDirectoryItem> employees;
  final List<LegalDirectoryItem> objects;
  final List<LegalCounterparty> counterparties;
  final List<LegalDirectoryItem> responsible;
  final List<LegalDocument> documents;

  const _MatterDirectories({
    required this.employees,
    required this.objects,
    required this.counterparties,
    required this.responsible,
    required this.documents,
  });
}
