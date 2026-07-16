part of 'legal_documents_screen.dart';

class LegalDocumentEditorScreen extends StatefulWidget {
  final LegalDocument? document;

  const LegalDocumentEditorScreen({super.key, this.document});

  @override
  State<LegalDocumentEditorScreen> createState() => _LegalDocumentEditorScreenState();
}

class _LegalDocumentEditorScreenState extends State<LegalDocumentEditorScreen> {
  final titleController = TextEditingController();
  final typeController = TextEditingController();
  final numberController = TextEditingController();
  final commentController = TextEditingController();
  final nextActionController = TextEditingController();
  String status = LegalDocumentStatus.draft;
  DateTime createdOn = DateTime.now();
  DateTime? expiresOn;
  DateTime? nextActionDueAt;
  String? employeeId;
  String? objectId;
  String? counterpartyId;
  String? responsibleId;
  bool foremanAction = false;
  bool managerApproval = false;
  bool saving = false;
  late Future<_DocumentDirectories> directoriesFuture;

  @override
  void initState() {
    super.initState();
    final item = widget.document;
    if (item != null) {
      titleController.text = item.title;
      typeController.text = item.documentType;
      numberController.text = item.documentNumber;
      commentController.text = item.comment;
      nextActionController.text = item.nextAction;
      status = item.status;
      createdOn = item.createdOn;
      expiresOn = item.expiresOn;
      nextActionDueAt = item.nextActionDueAt;
      employeeId = item.employeeId.isEmpty ? null : item.employeeId;
      objectId = item.objectId.isEmpty
          ? allObjectsScopeValue
          : item.objectId;
      counterpartyId = item.counterpartyId.isEmpty ? null : item.counterpartyId;
      responsibleId = item.responsibleUserId.isEmpty ? null : item.responsibleUserId;
      foremanAction = item.requiresForemanAction;
      managerApproval = item.requiresManagerApproval;
    }
    directoriesFuture = loadDirectories();
  }

  @override
  void dispose() {
    titleController.dispose();
    typeController.dispose();
    numberController.dispose();
    commentController.dispose();
    nextActionController.dispose();
    super.dispose();
  }

  Future<_DocumentDirectories> loadDirectories() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchEmployeeDirectory(),
      LegalRepository.fetchObjectDirectory(),
      LegalRepository.fetchCounterparties(),
      LegalRepository.fetchResponsibleDirectory(),
    ]);
    return _DocumentDirectories(
      employees: values[0] as List<LegalDirectoryItem>,
      objects: values[1] as List<LegalDirectoryItem>,
      counterparties: values[2] as List<LegalCounterparty>,
      responsible: values[3] as List<LegalDirectoryItem>,
    );
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Не указана';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<DateTime?> pickDate(DateTime? initial) {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<void> addCounterparty() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый контрагент'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Название')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Добавить')),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.length < 2) return;
    final saved = await LegalRepository.addCounterparty(name: result, category: 'other');
    if (mounted) {
      setState(() {
        counterpartyId = saved.id;
        directoriesFuture = loadDirectories();
      });
    }
  }

  Future<void> save() async {
    if (saving) return;
    if (titleController.text.trim().length < 2 || typeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажите название и тип документа')));
      return;
    }
    setState(() => saving = true);
    try {
      await LegalRepository.saveDocument(
        id: widget.document?.id,
        title: titleController.text,
        documentType: typeController.text,
        documentNumber: numberController.text,
        status: status,
        createdOn: createdOn,
        signedOn: status == LegalDocumentStatus.signed ? DateTime.now() : widget.document?.signedOn,
        validFrom: widget.document?.validFrom,
        expiresOn: expiresOn,
        responsibleUserId: responsibleId,
        employeeId: employeeId,
        objectId: isAllObjectsScope(objectId) ? null : objectId,
        counterpartyId: counterpartyId,
        taskId: widget.document?.taskId,
        legalMatterId: widget.document?.legalMatterId,
        comment: commentController.text,
        nextAction: nextActionController.text,
        nextActionDueAt: nextActionDueAt,
        requiresForemanAction: foremanAction,
        requiresManagerApproval: managerApproval,
        approvalStatus: widget.document?.approvalStatus ?? 'none',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  DropdownMenuItem<String> directoryItem(LegalDirectoryItem item) {
    return DropdownMenuItem<String>(
      value: item.id,
      child: Text(item.subtitle.isEmpty ? item.title : '${item.title} • ${item.subtitle}', overflow: TextOverflow.ellipsis),
    );
  }

  List<LegalDirectoryItem> employeesForObject(_DocumentDirectories data) {
    if (objectId == null) return const <LegalDirectoryItem>[];
    if (isAllObjectsScope(objectId)) {
      return List<LegalDirectoryItem>.from(data.employees);
    }
    String? selectedObject;
    for (final item in data.objects) {
      if (item.id == objectId) {
        selectedObject = item.title.trim().toLowerCase();
        break;
      }
    }
    if (selectedObject == null) return const <LegalDirectoryItem>[];
    return data.employees.where((employee) {
      return employee.objectName.trim().toLowerCase() == selectedObject;
    }).toList();
  }

  String employeeTitle(LegalDirectoryItem item) {
    if (isAllObjectsScope(objectId) && item.objectName.trim().isNotEmpty) {
      return '${item.title} — ${item.objectName.trim()}';
    }
    return item.subtitle.isEmpty
        ? item.title
        : '${item.title} • ${item.subtitle}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document == null ? 'Новый документ' : 'Редактировать документ')),
      body: AppPage(
        title: widget.document == null ? 'Новый документ' : 'Документ',
        subtitle: 'Основные сведения, связи, сроки и следующий шаг',
        child: FutureBuilder<_DocumentDirectories>(
          future: directoriesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Ошибка загрузки справочников: ${snapshot.error}');
              return const PremiumWorkCard(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())));
            }
            final data = snapshot.data!;
            final availableEmployees = employeesForObject(data);
            final objectFieldValue = isAllObjectsScope(objectId) ||
                    data.objects.any((item) => item.id == objectId)
                ? objectId
                : null;
            final employeeFieldValue = availableEmployees
                    .any((item) => item.id == employeeId)
                ? employeeId
                : null;
            return Column(
              children: [
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название документа')),
                      const SizedBox(height: 12),
                      TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Тип документа')),
                      const SizedBox(height: 12),
                      TextField(controller: numberController, decoration: const InputDecoration(labelText: 'Номер')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Статус'),
                        items: LegalDocumentStatus.values.map((value) => DropdownMenuItem(value: value, child: Text(LegalDocumentStatus.title(value)))).toList(),
                        onChanged: saving ? null : (value) => setState(() => status = value ?? LegalDocumentStatus.draft),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Дата документа'),
                        subtitle: Text(dateText(createdOn)),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final value = await pickDate(createdOn);
                          if (value != null) setState(() => createdOn = value);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Действует до'),
                        subtitle: Text(dateText(expiresOn)),
                        trailing: const Icon(Icons.event_outlined),
                        onTap: () async {
                          final value = await pickDate(expiresOn);
                          if (value != null) setState(() => expiresOn = value);
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
                        initialValue: objectFieldValue,
                        decoration: const InputDecoration(
                          labelText: 'Объект',
                          hintText: 'Сначала выберите объект',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: allObjectsScopeValue,
                            child: Text('Все объекты'),
                          ),
                          ...data.objects.map(directoryItem),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setState(() {
                                  objectId = value;
                                  employeeId = null;
                                }),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('legal-document-employee-${objectId ?? 'none'}'),
                        initialValue: employeeFieldValue,
                        decoration: InputDecoration(
                          labelText: 'Сотрудник',
                          hintText: objectId == null
                              ? 'Сначала выберите объект'
                              : availableEmployees.isEmpty
                                  ? 'На выбранном объекте нет сотрудников'
                                  : 'Выберите сотрудника',
                        ),
                        items: availableEmployees
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(
                                  employeeTitle(item),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving || objectId == null
                            ? null
                            : (value) => setState(() => employeeId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: data.counterparties.any((item) => item.id == counterpartyId) ? counterpartyId : null,
                              decoration: const InputDecoration(labelText: 'Контрагент'),
                              items: data.counterparties.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: saving ? null : (value) => setState(() => counterpartyId = value),
                            ),
                          ),
                          IconButton(onPressed: saving ? null : addCounterparty, icon: const Icon(Icons.add_business_outlined)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.responsible.any((item) => item.id == responsibleId) ? responsibleId : null,
                        decoration: const InputDecoration(labelText: 'Ответственный'),
                        items: data.responsible.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => responsibleId = value),
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
                      TextField(controller: nextActionController, decoration: const InputDecoration(labelText: 'Следующий шаг')),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Срок следующего шага'),
                        subtitle: Text(dateText(nextActionDueAt)),
                        trailing: const Icon(Icons.schedule_outlined),
                        onTap: () async {
                          final value = await pickDate(nextActionDueAt);
                          if (value != null) setState(() => nextActionDueAt = value);
                        },
                      ),
                      TextField(controller: commentController, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Комментарий', alignLabelWithHint: true)),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Требуется действие прораба'),
                        value: foremanAction,
                        onChanged: saving ? null : (value) => setState(() => foremanAction = value),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Требуется согласование руководителя'),
                        value: managerApproval,
                        onChanged: saving ? null : (value) => setState(() => managerApproval = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumActionButton(
                  label: widget.document == null ? 'Создать документ' : 'Сохранить документ',
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

class _DocumentDirectories {
  final List<LegalDirectoryItem> employees;
  final List<LegalDirectoryItem> objects;
  final List<LegalCounterparty> counterparties;
  final List<LegalDirectoryItem> responsible;

  const _DocumentDirectories({
    required this.employees,
    required this.objects,
    required this.counterparties,
    required this.responsible,
  });
}
