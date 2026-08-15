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

  final courtCaseNumberController = TextEditingController();
  final courtNameController = TextEditingController();
  final courtPartiesController = TextEditingController();
  final claimAmountController = TextEditingController();
  final proceedingStageController = TextEditingController();

  String type = LegalMatterType.task;
  String risk = LegalRiskLevel.medium;
  String status = LegalMatterStatus.open;
  DateTime? dueAt;
  DateTime? nextHearingAt;
  DateTime? outgoingSentAt;
  DateTime? responseDueAt;
  String? employeeId;
  String? objectId;
  String? counterpartyId;
  String? documentId;
  String? responsibleId;
  bool foremanAction = false;
  bool managerDecision = false;
  bool saving = false;
  late Future<_MatterEditorData> editorFuture;

  bool get isCourt => type == legalCourtMatterType;
  bool get isClaim => type == LegalMatterType.claim;

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
      objectId = item.objectId.isEmpty ? allObjectsScopeValue : item.objectId;
      counterpartyId = item.counterpartyId.isEmpty ? null : item.counterpartyId;
      documentId = item.documentId.isEmpty ? null : item.documentId;
      responsibleId = item.responsibleUserId.isEmpty ? null : item.responsibleUserId;
      foremanAction = item.requiresForemanAction;
      managerDecision = item.requiresManagerDecision;
    }
    editorFuture = loadData();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    actionsController.dispose();
    resultController.dispose();
    managerQuestionController.dispose();
    courtCaseNumberController.dispose();
    courtNameController.dispose();
    courtPartiesController.dispose();
    claimAmountController.dispose();
    proceedingStageController.dispose();
    super.dispose();
  }

  Future<_MatterEditorData> loadData() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchEmployeeDirectory(),
      LegalRepository.fetchObjectDirectory(),
      LegalRepository.fetchCounterparties(),
      LegalRepository.fetchResponsibleDirectory(),
      LegalRepository.fetchDocuments(),
      if (widget.matter != null)
        LegalProcessRepository.fetchDetails(widget.matter!.id)
      else
        Future<LegalMatterProcessDetails>.value(
          const LegalMatterProcessDetails.empty(''),
        ),
    ]);
    final process = values[5] as LegalMatterProcessDetails;
    courtCaseNumberController.text = process.courtCaseNumber;
    courtNameController.text = process.courtName;
    courtPartiesController.text = process.courtParties;
    claimAmountController.text = process.claimAmount?.toString() ?? '';
    proceedingStageController.text = process.proceedingStage;
    nextHearingAt = process.nextHearingAt;
    outgoingSentAt = process.outgoingSentAt;
    responseDueAt = process.responseDueAt;

    return _MatterEditorData(
      directories: _MatterDirectories(
        employees: values[0] as List<LegalDirectoryItem>,
        objects: values[1] as List<LegalDirectoryItem>,
        counterparties: values[2] as List<LegalCounterparty>,
        responsible: values[3] as List<LegalDirectoryItem>,
        documents: values[4] as List<LegalDocument>,
      ),
    );
  }

  DropdownMenuItem<String> directoryItem(LegalDirectoryItem item) {
    return DropdownMenuItem(
      value: item.id,
      child: Text(item.title, overflow: TextOverflow.ellipsis),
    );
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Не указан';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Future<DateTime?> pickDate(DateTime? current) {
    return showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  Future<DateTime?> pickDateTime(DateTime? current) async {
    final date = await pickDate(current);
    if (date == null || !mounted) return current;
    final initial = current == null
        ? const TimeOfDay(hour: 10, minute: 0)
        : TimeOfDay(hour: current.hour, minute: current.minute);
    final time = await showTimePicker(context: context, initialTime: initial);
    if (time == null) return current;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget dateField({
    required String title,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool withTime = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        value == null
            ? 'Не указан'
            : withTime
                ? '${dateText(value)} • ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
                : dateText(value),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            IconButton(
              tooltip: 'Очистить',
              onPressed: saving ? null : () => onChanged(null),
              icon: const Icon(Icons.close_rounded),
            ),
          const Icon(Icons.calendar_month_outlined),
        ],
      ),
      onTap: saving
          ? null
          : () async {
              final selected = withTime
                  ? await pickDateTime(value)
                  : await pickDate(value);
              if (mounted && selected != value) onChanged(selected);
            },
    );
  }

  Future<void> save() async {
    if (saving) return;
    if (titleController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название дела')),
      );
      return;
    }
    final amountText = claimAmountController.text.trim().replaceAll(',', '.');
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сумма требований указана неверно')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final saved = await LegalRepository.saveMatter(
        id: widget.matter?.id,
        matterType: type,
        title: titleController.text,
        description: descriptionController.text,
        riskLevel: risk,
        status: status,
        dueAt: dueAt,
        responsibleUserId: responsibleId,
        employeeId: employeeId,
        objectId: isAllObjectsScope(objectId) ? null : objectId,
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

      await LegalProcessRepository.saveDetails(
        matterId: saved.id,
        courtCaseNumber: isCourt ? courtCaseNumberController.text : '',
        courtName: isCourt ? courtNameController.text : '',
        courtParties: isCourt ? courtPartiesController.text : '',
        claimAmount: isCourt || isClaim ? amount : null,
        proceedingStage: isCourt || isClaim ? proceedingStageController.text : '',
        nextHearingAt: isCourt ? nextHearingAt : null,
        outgoingSentAt: isClaim ? outgoingSentAt : null,
        responseDueAt: isCourt || isClaim ? responseDueAt : null,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $error')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<LegalDirectoryItem> employeesForObject(_MatterDirectories data) {
    if (objectId == null) return const <LegalDirectoryItem>[];
    if (isAllObjectsScope(objectId)) return List<LegalDirectoryItem>.from(data.employees);
    String? selectedObject;
    for (final item in data.objects) {
      if (item.id == objectId) {
        selectedObject = item.title.trim().toLowerCase();
        break;
      }
    }
    if (selectedObject == null) return const <LegalDirectoryItem>[];
    return data.employees
        .where((employee) => employee.objectName.trim().toLowerCase() == selectedObject)
        .toList();
  }

  String employeeTitle(LegalDirectoryItem item) {
    if (isAllObjectsScope(objectId) && item.objectName.trim().isNotEmpty) {
      return '${item.title} — ${item.objectName.trim()}';
    }
    return item.subtitle.isEmpty ? item.title : '${item.title} • ${item.subtitle}';
  }

  Widget basicCard() {
    final typeValues = <String>[...LegalMatterType.values, legalCourtMatterType];
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название *')),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Суть дела', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: typeValues.contains(type) ? type : LegalMatterType.other,
            decoration: const InputDecoration(labelText: 'Тип дела'),
            items: typeValues
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == legalCourtMatterType
                          ? 'Судебное дело'
                          : LegalMatterType.title(value),
                    ),
                  ),
                )
                .toList(),
            onChanged: saving ? null : (value) => setState(() => type = value ?? LegalMatterType.task),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: risk,
                  decoration: const InputDecoration(labelText: 'Риск'),
                  items: LegalRiskLevel.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(LegalRiskLevel.title(value))))
                      .toList(),
                  onChanged: saving ? null : (value) => setState(() => risk = value ?? LegalRiskLevel.medium),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: LegalMatterStatus.values
                      .map((value) => DropdownMenuItem(value: value, child: Text(LegalMatterStatus.title(value))))
                      .toList(),
                  onChanged: saving ? null : (value) => setState(() => status = value ?? LegalMatterStatus.open),
                ),
              ),
            ],
          ),
          dateField(title: 'Общий срок по делу', value: dueAt, onChanged: (value) => setState(() => dueAt = value)),
        ],
      ),
    );
  }

  Widget linksCard(_MatterDirectories data) {
    final availableEmployees = employeesForObject(data);
    final objectFieldValue = isAllObjectsScope(objectId) || data.objects.any((item) => item.id == objectId) ? objectId : null;
    final employeeFieldValue = availableEmployees.any((item) => item.id == employeeId) ? employeeId : null;

    return PremiumWorkCard(
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
            initialValue: objectFieldValue,
            decoration: const InputDecoration(labelText: 'Объект'),
            items: [
              const DropdownMenuItem<String>(value: allObjectsScopeValue, child: Text('Все объекты')),
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
            key: ValueKey('legal-matter-employee-${objectId ?? 'none'}'),
            initialValue: employeeFieldValue,
            decoration: InputDecoration(
              labelText: 'Сотрудник',
              hintText: objectId == null
                  ? 'Сначала выберите объект'
                  : availableEmployees.isEmpty
                      ? 'На объекте нет сотрудников'
                      : 'Выберите сотрудника',
            ),
            items: availableEmployees
                .map((item) => DropdownMenuItem<String>(value: item.id, child: Text(employeeTitle(item), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: saving || objectId == null ? null : (value) => setState(() => employeeId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: data.counterparties.any((item) => item.id == counterpartyId) ? counterpartyId : null,
            decoration: const InputDecoration(labelText: 'Контрагент'),
            items: data.counterparties
                .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: saving ? null : (value) => setState(() => counterpartyId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: data.documents.any((item) => item.id == documentId) ? documentId : null,
            decoration: const InputDecoration(labelText: 'Основной документ'),
            items: data.documents
                .map((item) => DropdownMenuItem(value: item.id, child: Text(item.title, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: saving ? null : (value) => setState(() => documentId = value),
          ),
        ],
      ),
    );
  }

  Widget processCard() {
    if (!isCourt && !isClaim) return const SizedBox.shrink();
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isCourt ? 'Судебное дело' : 'Претензионная работа',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          if (isCourt) ...[
            TextField(controller: courtCaseNumberController, decoration: const InputDecoration(labelText: 'Номер дела')),
            const SizedBox(height: 12),
            TextField(controller: courtNameController, decoration: const InputDecoration(labelText: 'Суд')),
            const SizedBox(height: 12),
            TextField(
              controller: courtPartiesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Стороны', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: claimAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Сумма требований, ₽'),
          ),
          const SizedBox(height: 12),
          TextField(controller: proceedingStageController, decoration: const InputDecoration(labelText: 'Текущая стадия')),
          if (isCourt) ...[
            const SizedBox(height: 4),
            dateField(
              title: 'Ближайшее заседание',
              value: nextHearingAt,
              withTime: true,
              onChanged: (value) => setState(() => nextHearingAt = value),
            ),
          ],
          if (isClaim) ...[
            const SizedBox(height: 4),
            dateField(
              title: 'Дата отправки претензии',
              value: outgoingSentAt,
              onChanged: (value) => setState(() => outgoingSentAt = value),
            ),
          ],
          dateField(
            title: isCourt ? 'Процессуальный срок / срок ответа' : 'Срок ответа на претензию',
            value: responseDueAt,
            onChanged: (value) => setState(() => responseDueAt = value),
          ),
        ],
      ),
    );
  }

  Widget actionsCard() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          TextField(
            controller: actionsController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Что нужно сделать', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: resultController,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Результат / итог', alignLabelWithHint: true),
          ),
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
            TextField(
              controller: managerQuestionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Что должен решить руководитель', alignLabelWithHint: true),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.matter == null ? 'Новое дело' : 'Редактировать дело'),
      ),
      body: AppPage(
        title: widget.matter == null ? 'Новое юридическое дело' : 'Юридическое дело',
        subtitle: 'Один экран для обычной работы, претензий и судебных дел',
        child: FutureBuilder<_MatterEditorData>(
          future: editorFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final directories = snapshot.data!.directories;
            return Column(
              children: [
                basicCard(),
                const SizedBox(height: 12),
                linksCard(directories),
                if (isCourt || isClaim) ...[
                  const SizedBox(height: 12),
                  processCard(),
                ],
                const SizedBox(height: 12),
                actionsCard(),
                const SizedBox(height: 14),
                PremiumActionButton(
                  label: widget.matter == null ? 'Создать дело' : 'Сохранить дело',
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

class _MatterEditorData {
  final _MatterDirectories directories;

  const _MatterEditorData({required this.directories});
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
