import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_process_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_document_complete_screen.dart';
import 'legal_employee_complete_screen.dart';
import 'legal_matter_complete_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalBaseCompleteScreen extends StatefulWidget {
  const LegalBaseCompleteScreen({super.key});

  @override
  State<LegalBaseCompleteScreen> createState() =>
      _LegalBaseCompleteScreenState();
}

class _LegalBaseCompleteScreenState extends State<LegalBaseCompleteScreen> {
  late Future<_LegalBaseData> future;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_LegalBaseData> load() async {
    final values = await Future.wait<dynamic>([
      LegalWorkspaceRepository.fetchEmployees(),
      LegalWorkspaceRepository.fetchObjects(),
      LegalRepository.fetchCounterparties(),
    ]);
    return _LegalBaseData(
      employees: values[0] as List<LegalWorkspaceEmployee>,
      objects: values[1] as List<LegalWorkspaceObject>,
      counterparties: values[2] as List<LegalCounterparty>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  bool matches(String value) {
    final query = searchController.text.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AppPage(
        title: 'База юриста',
        subtitle:
            'Сотрудники, объекты и контрагенты — единая история и документы',
        headerTrailing: IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        child: Column(
          children: [
            PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Поиск по ФИО, объекту или контрагенту',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Сотрудники'),
                      Tab(text: 'Объекты'),
                      Tab(text: 'Контрагенты'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<_LegalBaseData>(
              future: future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  if (snapshot.hasError) {
                    return PremiumWorkCard(
                      child: Text(
                        'Не удалось загрузить базу: ${snapshot.error}',
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
                final employees = data.employees
                    .where(
                      (item) => matches(
                        '${item.fio} ${item.position} ${item.objectName}',
                      ),
                    )
                    .toList();
                final objects = data.objects
                    .where((item) => matches('${item.name} ${item.address}'))
                    .toList();
                final counterparties = data.counterparties
                    .where(
                      (item) => matches(
                        '${item.name} ${item.inn} ${item.contactName}',
                      ),
                    )
                    .toList();
                return SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.67,
                  child: TabBarView(
                    children: [
                      _EmployeeDirectory(items: employees),
                      _ObjectDirectory(items: objects),
                      _CounterpartyDirectory(items: counterparties),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeDirectory extends StatelessWidget {
  final List<LegalWorkspaceEmployee> items;

  const _EmployeeDirectory({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('Сотрудники не найдены'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumWorkCard(
            radius: 20,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.person_outline_rounded),
              ),
              title: Text(
                item.fio,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                <String>[
                  if (item.position.isNotEmpty) item.position,
                  if (item.objectName.isNotEmpty) item.objectName,
                  item.isActive ? 'работает' : 'уволен / неактивен',
                  '${item.documentsCount} док.',
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                AppPageRoute<void>(
                  builder: (_) => LegalEmployeeCompleteScreen(employee: item),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ObjectDirectory extends StatelessWidget {
  final List<LegalWorkspaceObject> items;

  const _ObjectDirectory({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Center(child: Text('Объекты не найдены'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumWorkCard(
            radius: 20,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.apartment_outlined),
              ),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                <String>[
                  if (item.address.isNotEmpty) item.address,
                  '${item.employeesCount} сотр.',
                  '${item.contractsCount} дог.',
                  '${item.openMattersCount} открытых дел',
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                AppPageRoute<void>(
                  builder: (_) => LegalObjectCompleteScreen(object: item),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CounterpartyDirectory extends StatelessWidget {
  final List<LegalCounterparty> items;

  const _CounterpartyDirectory({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return const Center(child: Text('Контрагенты не найдены'));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumWorkCard(
            radius: 20,
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                <String>[
                  if (item.inn.isNotEmpty) 'ИНН ${item.inn}',
                  if (item.contactName.isNotEmpty) item.contactName,
                  item.status,
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                AppPageRoute<void>(
                  builder: (_) =>
                      LegalCounterpartyCompleteScreen(counterparty: item),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LegalObjectCompleteScreen extends StatefulWidget {
  final LegalWorkspaceObject object;

  const LegalObjectCompleteScreen({super.key, required this.object});

  @override
  State<LegalObjectCompleteScreen> createState() =>
      _LegalObjectCompleteScreenState();
}

class _LegalObjectCompleteScreenState extends State<LegalObjectCompleteScreen> {
  late Future<_ObjectCompleteData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_ObjectCompleteData> load() async {
    final values = await Future.wait<dynamic>([
      LegalOperationsRepository.fetchObjectProfile(widget.object.id),
      LegalWorkspaceRepository.fetchDocuments(objectId: widget.object.id),
      LegalWorkspaceRepository.fetchEmployees(),
      LegalRepository.fetchMatters(),
      LegalRepository.fetchCounterparties(),
      LegalRepository.fetchResponsibleDirectory(),
      LegalRepository.fetchDocuments(),
    ]);
    return _ObjectCompleteData(
      profile: values[0] as LegalObjectProfile,
      workspaceDocuments: values[1] as List<LegalWorkspaceDocument>,
      employees: (values[2] as List<LegalWorkspaceEmployee>)
          .where((item) => item.objectId == widget.object.id)
          .toList(),
      matters: (values[3] as List<LegalMatter>)
          .where((item) => item.objectId == widget.object.id)
          .toList(),
      counterparties: values[4] as List<LegalCounterparty>,
      responsibles: values[5] as List<LegalDirectoryItem>,
      legalDocuments: (values[6] as List<LegalDocument>)
          .where((item) => item.objectId == widget.object.id)
          .toList(),
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

  String money(double? value) {
    if (value == null) return '—';
    return '${value.round()} ₽';
  }

  String responsibleName(_ObjectCompleteData data) {
    for (final item in data.responsibles) {
      if (item.id == data.profile.responsibleUserId) return item.title;
    }
    return '';
  }

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

  Future<void> editProfile(_ObjectCompleteData data) async {
    String customerId = data.profile.customerCounterpartyId;
    String contractId = data.profile.mainContractDocumentId;
    String responsibleId = data.profile.responsibleUserId;
    final valueController = TextEditingController(
      text: data.profile.contractValue?.toStringAsFixed(0) ?? '',
    );
    final notesController = TextEditingController(text: data.profile.notes);
    DateTime? start = data.profile.contractStart;
    DateTime? end = data.profile.contractEnd;
    final contracts = data.legalDocuments.where((item) {
      final text = '${item.documentType} ${item.title}'.toLowerCase();
      return text.contains('договор') ||
          text.contains('контракт') ||
          text.contains('соглашен');
    }).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Юридическая карточка объекта'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: customerId.isEmpty ? null : customerId,
                    decoration: const InputDecoration(
                      labelText: 'Заказчик / контрагент',
                    ),
                    items: data.counterparties
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => customerId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: contractId.isEmpty ? null : contractId,
                    decoration: const InputDecoration(
                      labelText: 'Основной договор',
                    ),
                    items: contracts
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => contractId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: responsibleId.isEmpty ? null : responsibleId,
                    decoration: const InputDecoration(
                      labelText: 'Ответственный',
                    ),
                    items: data.responsibles
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => responsibleId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Стоимость договора',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Начало договора'),
                    subtitle: Text(date(start)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => start = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Окончание договора'),
                    subtitle: Text(date(end)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: end ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDialogState(() => end = picked);
                    },
                  ),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Комментарий'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await LegalOperationsRepository.saveObjectProfile(
        objectId: widget.object.id,
        customerCounterpartyId: customerId,
        mainContractDocumentId: contractId,
        responsibleUserId: responsibleId,
        contractValue: double.tryParse(
          valueController.text.replaceAll(',', '.'),
        ),
        contractStart: start,
        contractEnd: end,
        notes: notesController.text,
      );
      if (mounted) await refresh();
    }
    valueController.dispose();
    notesController.dispose();
  }

  Widget documents(_ObjectCompleteData data, String group, String title) {
    final items = data.workspaceDocuments.where((item) {
      if (group == 'contract') return item.category == 'contract';
      if (group == 'act') return item.category == 'act';
      return item.category != 'contract' && item.category != 'act';
    }).toList();
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Нет документов')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    if (item.documentType.isNotEmpty) item.documentType,
                    if (item.status.isNotEmpty) item.status,
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () async {
                  if (item.legalDocumentId.isNotEmpty) {
                    final doc = await LegalRepository.fetchDocument(
                      item.legalDocumentId,
                    );
                    if (!mounted) return;
                    await Navigator.push<void>(
                      context,
                      AppPageRoute<void>(
                        builder: (_) =>
                            LegalDocumentCompleteScreen(document: doc),
                      ),
                    );
                  } else if (item.hasStoredFile) {
                    await LegalWorkspaceRepository.openStoredFile(
                      bucketName: item.bucketName,
                      storagePath: item.storagePath,
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.object.name),
        actions: [
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_ObjectCompleteData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError)
              return Center(
                child: Text('Не удалось загрузить объект: ${snapshot.error}'),
              );
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final courts = data.matters.where(legalMatterIsCourt).toList();
          final claims = data.matters
              .where((item) => item.matterType == LegalMatterType.claim)
              .toList();
          return AppPage(
            title: data.profile.objectName,
            subtitle: data.profile.address,
            headerTrailing: FilledButton.tonalIcon(
              onPressed: () => editProfile(data),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Карточка'),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Юридический профиль объекта',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      line('Заказчик', data.profile.customerName),
                      line('Основной договор', data.profile.mainContractTitle),
                      line('Ответственный', responsibleName(data)),
                      line('Стоимость', money(data.profile.contractValue)),
                      line('Договор с', date(data.profile.contractStart)),
                      line('Договор до', date(data.profile.contractEnd)),
                      line('Комментарий', data.profile.notes),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                documents(data, 'contract', 'Договоры и допсоглашения'),
                const SizedBox(height: 12),
                documents(data, 'act', 'Акты'),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Сотрудники • ${data.employees.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      ...data.employees.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.fio,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(item.position),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push<void>(
                            context,
                            AppPageRoute<void>(
                              builder: (_) =>
                                  LegalEmployeeCompleteScreen(employee: item),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _MatterGroup(title: 'Претензии', items: claims),
                const SizedBox(height: 12),
                _MatterGroup(title: 'Судебные дела', items: courts),
                const SizedBox(height: 12),
                _MatterGroup(
                  title: 'Остальные юридические дела',
                  items: data.matters
                      .where(
                        (item) =>
                            !legalMatterIsCourt(item) &&
                            item.matterType != LegalMatterType.claim,
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MatterGroup extends StatelessWidget {
  final String title;
  final List<LegalMatter> items;

  const _MatterGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title • ${items.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Нет записей'),
            )
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('${item.statusTitle} • ${item.riskTitle} риск'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  AppPageRoute<void>(
                    builder: (_) => LegalMatterCompleteScreen(matter: item),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LegalCounterpartyCompleteScreen extends StatefulWidget {
  final LegalCounterparty counterparty;

  const LegalCounterpartyCompleteScreen({
    super.key,
    required this.counterparty,
  });

  @override
  State<LegalCounterpartyCompleteScreen> createState() =>
      _LegalCounterpartyCompleteScreenState();
}

class _LegalCounterpartyCompleteScreenState
    extends State<LegalCounterpartyCompleteScreen> {
  late Future<_CounterpartyCompleteData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_CounterpartyCompleteData> load() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchDocuments(),
      LegalRepository.fetchMatters(),
    ]);
    return _CounterpartyCompleteData(
      documents: (values[0] as List<LegalDocument>)
          .where((item) => item.counterpartyId == widget.counterparty.id)
          .toList(),
      matters: (values[1] as List<LegalMatter>)
          .where((item) => item.counterpartyId == widget.counterparty.id)
          .toList(),
    );
  }

  bool contract(LegalDocument item) {
    final text = '${item.documentType} ${item.title}'.toLowerCase();
    return text.contains('договор') ||
        text.contains('контракт') ||
        text.contains('соглашен');
  }

  bool act(LegalDocument item) =>
      '${item.documentType} ${item.title}'.toLowerCase().contains('акт');

  Widget info() {
    final c = widget.counterparty;
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Реквизиты и контакты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (c.inn.isNotEmpty) Text('ИНН: ${c.inn}'),
          if (c.kpp.isNotEmpty) Text('КПП: ${c.kpp}'),
          if (c.ogrn.isNotEmpty) Text('ОГРН: ${c.ogrn}'),
          if (c.contactName.isNotEmpty) Text('Контакт: ${c.contactName}'),
          if (c.phone.isNotEmpty) Text('Телефон: ${c.phone}'),
          if (c.email.isNotEmpty) Text('E-mail: ${c.email}'),
          if (c.comment.isNotEmpty) Text('Комментарий: ${c.comment}'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.counterparty.name)),
      body: FutureBuilder<_CounterpartyCompleteData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError)
              return Center(
                child: Text(
                  'Не удалось загрузить контрагента: ${snapshot.error}',
                ),
              );
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final objectNames = <String>{
            ...data.documents
                .map((item) => item.objectName)
                .where((value) => value.isNotEmpty),
            ...data.matters
                .map((item) => item.objectName)
                .where((value) => value.isNotEmpty),
          }.toList()..sort();
          return AppPage(
            title: widget.counterparty.name,
            subtitle: <String>[
              if (widget.counterparty.inn.isNotEmpty)
                'ИНН ${widget.counterparty.inn}',
              widget.counterparty.status,
            ].join(' • '),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info(),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Связанные объекты • ${objectNames.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (objectNames.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Связей с объектами пока нет'),
                        ),
                      ...objectNames.map(
                        (value) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _CounterpartyDocumentGroup(
                  title: 'Договоры',
                  items: data.documents.where(contract).toList(),
                ),
                const SizedBox(height: 12),
                _CounterpartyDocumentGroup(
                  title: 'Акты',
                  items: data.documents.where(act).toList(),
                ),
                const SizedBox(height: 12),
                _CounterpartyDocumentGroup(
                  title: 'Другие документы',
                  items: data.documents
                      .where((item) => !contract(item) && !act(item))
                      .toList(),
                ),
                const SizedBox(height: 12),
                _MatterGroup(
                  title: 'Претензии',
                  items: data.matters
                      .where((item) => item.matterType == LegalMatterType.claim)
                      .toList(),
                ),
                const SizedBox(height: 12),
                _MatterGroup(
                  title: 'Судебные дела',
                  items: data.matters.where(legalMatterIsCourt).toList(),
                ),
                const SizedBox(height: 12),
                _MatterGroup(
                  title: 'Остальные дела',
                  items: data.matters
                      .where(
                        (item) =>
                            item.matterType != LegalMatterType.claim &&
                            !legalMatterIsCourt(item),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CounterpartyDocumentGroup extends StatelessWidget {
  final String title;
  final List<LegalDocument> items;

  const _CounterpartyDocumentGroup({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title • ${items.length}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Нет документов'),
            ),
          ...items.map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('${item.statusTitle} • ${item.expiryTitle}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                AppPageRoute<void>(
                  builder: (_) => LegalDocumentCompleteScreen(document: item),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalBaseData {
  final List<LegalWorkspaceEmployee> employees;
  final List<LegalWorkspaceObject> objects;
  final List<LegalCounterparty> counterparties;

  const _LegalBaseData({
    required this.employees,
    required this.objects,
    required this.counterparties,
  });
}

class _ObjectCompleteData {
  final LegalObjectProfile profile;
  final List<LegalWorkspaceDocument> workspaceDocuments;
  final List<LegalWorkspaceEmployee> employees;
  final List<LegalMatter> matters;
  final List<LegalCounterparty> counterparties;
  final List<LegalDirectoryItem> responsibles;
  final List<LegalDocument> legalDocuments;

  const _ObjectCompleteData({
    required this.profile,
    required this.workspaceDocuments,
    required this.employees,
    required this.matters,
    required this.counterparties,
    required this.responsibles,
    required this.legalDocuments,
  });
}

class _CounterpartyCompleteData {
  final List<LegalDocument> documents;
  final List<LegalMatter> matters;

  const _CounterpartyCompleteData({
    required this.documents,
    required this.matters,
  });
}
