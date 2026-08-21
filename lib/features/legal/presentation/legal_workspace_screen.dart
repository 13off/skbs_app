import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_process_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import 'legal_employee_dossier_screen.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

/// Единая база юриста.
///
/// Здесь намеренно нет повторных вкладок «Документы», «Дела», «Суды» и
/// «Претензии»: для них есть отдельные основные разделы оболочки юриста.
/// База отвечает только на вопрос «с кем/с чем связана юридическая работа».
class LegalWorkspaceScreen extends StatefulWidget {
  const LegalWorkspaceScreen({super.key});

  @override
  State<LegalWorkspaceScreen> createState() => _LegalWorkspaceScreenState();
}

class _LegalWorkspaceScreenState extends State<LegalWorkspaceScreen> {
  final searchController = TextEditingController();
  late Future<_LegalBaseData> future;
  StreamSubscription<AppDataChange>? subscription;
  String search = '';

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.legal)) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<_LegalBaseData> load() async {
    final values = await Future.wait<dynamic>([
      LegalWorkspaceRepository.fetchSnapshot(),
      LegalRepository.fetchMatters(),
      LegalRepository.fetchCounterparties(),
      LegalRepository.fetchDocuments(),
    ]);
    return _LegalBaseData(
      workspace: values[0] as LegalWorkspaceSnapshot,
      matters: values[1] as List<LegalMatter>,
      counterparties: values[2] as List<LegalCounterparty>,
      legalDocuments: values[3] as List<LegalDocument>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  bool matches(String value) {
    final query = search.trim().toLowerCase();
    return query.isEmpty || value.toLowerCase().contains(query);
  }

  Widget message(String text, {IconData icon = Icons.check_circle_outline}) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget employees(_LegalBaseData data) {
    final items = data.workspace.employees
        .where(
          (item) => matches('${item.fio} ${item.position} ${item.objectName}'),
        )
        .toList();
    if (items.isEmpty)
      return message('Сотрудники не найдены', icon: Icons.search_off);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return PremiumWorkCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              child: Text(
                item.fio.trim().isEmpty
                    ? '?'
                    : item.fio.trim()[0].toUpperCase(),
              ),
            ),
            title: Text(
              item.fio,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              <String>[
                if (item.position.isNotEmpty) item.position,
                if (item.objectName.isNotEmpty) item.objectName,
                '${item.documentsCount} документов • ${item.mattersCount} дел',
                if (item.finesCount > 0)
                  '${item.finesCount} взысканий${item.pendingFinesCount > 0 ? ' • ${item.pendingFinesCount} ожидают' : ''}',
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(
              context,
              AppPageRoute<void>(
                builder: (_) => LegalEmployeeDossierScreen(employee: item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget objects(_LegalBaseData data) {
    final items = data.workspace.objects
        .where((item) => matches('${item.name} ${item.address}'))
        .toList();
    if (items.isEmpty)
      return message('Объекты не найдены', icon: Icons.search_off);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return PremiumWorkCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              <String>[
                if (item.address.isNotEmpty) item.address,
                '${item.employeesCount} сотрудников • ${item.contractsCount} договоров • ${item.actsCount} актов',
                '${item.mattersCount} дел${item.openMattersCount > 0 ? ' • ${item.openMattersCount} открыто' : ''}',
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(
              context,
              AppPageRoute<void>(
                builder: (_) => _ObjectLegalDossierScreen(
                  object: item,
                  documents: data.workspace.documents
                      .where((document) => document.objectId == item.id)
                      .toList(),
                  matters: data.matters
                      .where((matter) => matter.objectId == item.id)
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget counterparties(_LegalBaseData data) {
    final items = data.counterparties
        .where(
          (item) => matches(
            '${item.name} ${item.inn} ${item.contactName} ${item.phone} ${item.email}',
          ),
        )
        .toList();
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        children: [
          message(
            'Контрагенты пока не добавлены',
            icon: Icons.business_outlined,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: openAddCounterparty,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить контрагента'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final documents = data.legalDocuments
            .where((document) => document.counterpartyId == item.id)
            .toList();
        final matters = data.matters
            .where((matter) => matter.counterpartyId == item.id)
            .toList();
        return PremiumWorkCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              <String>[
                if (item.inn.isNotEmpty) 'ИНН ${item.inn}',
                if (item.contactName.isNotEmpty) item.contactName,
                '${documents.length} документов • ${matters.length} дел',
              ].join('\n'),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(
              context,
              AppPageRoute<void>(
                builder: (_) => _CounterpartyDossierScreen(
                  counterparty: item,
                  documents: documents,
                  matters: matters,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openAddCounterparty() async {
    final name = TextEditingController();
    final inn = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый контрагент'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: inn,
                decoration: const InputDecoration(labelText: 'ИНН'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: contact,
                decoration: const InputDecoration(labelText: 'Контактное лицо'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Телефон'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    if (accepted == true && name.text.trim().length >= 2) {
      await LegalRepository.addCounterparty(
        name: name.text,
        category: 'contractor',
        inn: inn.text,
        contactName: contact.text,
        phone: phone.text,
        email: email.text,
      );
      if (mounted) await refresh();
    }
    name.dispose();
    inn.dispose();
    contact.dispose();
    phone.dispose();
    email.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_LegalBaseData>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: message(
                'Не удалось загрузить базу: ${snapshot.error}',
                icon: Icons.cloud_off_outlined,
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        return DefaultTabController(
          length: 3,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'База юриста',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Сотрудники, объекты и контрагенты — без дублирования документов и дел',
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Обновить',
                        onPressed: refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Поиск по ФИО, объекту, контрагенту, ИНН или контакту',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: search.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                searchController.clear();
                                setState(() => search = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (value) => setState(() => search = value),
                  ),
                ),
                const SizedBox(height: 6),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Сотрудники  ${data.workspace.employees.length}'),
                    Tab(text: 'Объекты  ${data.workspace.objects.length}'),
                    Tab(text: 'Контрагенты  ${data.counterparties.length}'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      employees(data),
                      objects(data),
                      counterparties(data),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LegalBaseData {
  final LegalWorkspaceSnapshot workspace;
  final List<LegalMatter> matters;
  final List<LegalCounterparty> counterparties;
  final List<LegalDocument> legalDocuments;

  const _LegalBaseData({
    required this.workspace,
    required this.matters,
    required this.counterparties,
    required this.legalDocuments,
  });
}

mixin _DossierHelpers<T extends StatefulWidget> on State<T> {
  String date(DateTime? value) {
    if (value == null) return '—';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String money(double value) {
    final raw = value.round().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
      buffer.write(raw[index]);
    }
    return '${buffer.toString()} ₽';
  }

  Widget section(String title, List<Widget> children, {String? emptyText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          PremiumWorkCard(
            radius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(emptyText ?? 'Данных пока нет'),
          )
        else
          ...children,
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> openWorkspaceDocument(LegalWorkspaceDocument item) async {
    if (item.legalDocumentId.isNotEmpty) {
      final document = await LegalRepository.fetchDocument(
        item.legalDocumentId,
      );
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalDocumentDetailsScreen(document: document),
        ),
      );
      return;
    }
    if (item.hasStoredFile) {
      await LegalWorkspaceRepository.openStoredFile(
        bucketName: item.bucketName,
        storagePath: item.storagePath,
      );
    }
  }

  Future<void> openLegalDocument(LegalDocument document) async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => LegalDocumentDetailsScreen(document: document),
      ),
    );
  }

  Future<void> openMatter(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: matter, canDecide: false),
      ),
    );
  }

  Widget workspaceDocumentTile(LegalWorkspaceDocument item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumWorkCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            item.category == 'contract'
                ? Icons.handshake_outlined
                : item.category == 'act'
                ? Icons.fact_check_outlined
                : Icons.description_outlined,
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            <String>[
              if (item.documentType.isNotEmpty) item.documentType,
              if (item.objectName.isNotEmpty) item.objectName,
              date(item.documentDate),
            ].join(' • '),
          ),
          trailing: const Icon(Icons.open_in_new_rounded),
          onTap: () => openWorkspaceDocument(item),
        ),
      ),
    );
  }

  Widget matterTile(LegalMatter matter) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PremiumWorkCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            legalMatterIsCourt(matter)
                ? Icons.account_balance_outlined
                : Icons.gavel_outlined,
          ),
          title: Text(
            matter.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            <String>[
              legalMatterDisplayType(matter),
              matter.statusTitle,
              if (matter.dueAt != null) 'срок ${date(matter.dueAt)}',
            ].join(' • '),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => openMatter(matter),
        ),
      ),
    );
  }
}

class _ObjectLegalDossierScreen extends StatefulWidget {
  final LegalWorkspaceObject object;
  final List<LegalWorkspaceDocument> documents;
  final List<LegalMatter> matters;

  const _ObjectLegalDossierScreen({
    required this.object,
    required this.documents,
    required this.matters,
  });

  @override
  State<_ObjectLegalDossierScreen> createState() =>
      _ObjectLegalDossierScreenState();
}

class _ObjectLegalDossierScreenState extends State<_ObjectLegalDossierScreen>
    with _DossierHelpers<_ObjectLegalDossierScreen> {
  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    return Scaffold(
      appBar: AppBar(title: Text(object.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  object.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (object.address.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(object.address),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(
                      '${object.employeesCount} сотрудников',
                      Icons.groups_2_outlined,
                    ),
                    _CountChip(
                      '${widget.documents.where((item) => item.category == 'contract').length} договоров',
                      Icons.handshake_outlined,
                    ),
                    _CountChip(
                      '${widget.documents.where((item) => item.category == 'act').length} актов',
                      Icons.fact_check_outlined,
                    ),
                    _CountChip(
                      '${widget.matters.length} дел',
                      Icons.gavel_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          section(
            'Документы объекта',
            widget.documents.map(workspaceDocumentTile).toList(),
            emptyText: 'Документы объекта пока не добавлены.',
          ),
          section(
            'Дела и риски',
            widget.matters.map(matterTile).toList(),
            emptyText: 'Связанных юридических дел нет.',
          ),
        ],
      ),
    );
  }
}

class _CounterpartyDossierScreen extends StatefulWidget {
  final LegalCounterparty counterparty;
  final List<LegalDocument> documents;
  final List<LegalMatter> matters;

  const _CounterpartyDossierScreen({
    required this.counterparty,
    required this.documents,
    required this.matters,
  });

  @override
  State<_CounterpartyDossierScreen> createState() =>
      _CounterpartyDossierScreenState();
}

class _CounterpartyDossierScreenState extends State<_CounterpartyDossierScreen>
    with _DossierHelpers<_CounterpartyDossierScreen> {
  @override
  Widget build(BuildContext context) {
    final item = widget.counterparty;
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (item.inn.isNotEmpty) Text('ИНН: ${item.inn}'),
                if (item.kpp.isNotEmpty) Text('КПП: ${item.kpp}'),
                if (item.ogrn.isNotEmpty) Text('ОГРН: ${item.ogrn}'),
                if (item.contactName.isNotEmpty)
                  Text('Контакт: ${item.contactName}'),
                if (item.phone.isNotEmpty) Text('Телефон: ${item.phone}'),
                if (item.email.isNotEmpty) Text('E-mail: ${item.email}'),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(
                      '${widget.documents.length} документов',
                      Icons.description_outlined,
                    ),
                    _CountChip(
                      '${widget.matters.length} дел',
                      Icons.gavel_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          section(
            'Документы',
            widget.documents
                .map(
                  (document) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumWorkCard(
                      radius: 20,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(
                          document.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${document.documentType} • ${document.statusTitle}',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => openLegalDocument(document),
                      ),
                    ),
                  ),
                )
                .toList(),
            emptyText: 'Документов с этим контрагентом пока нет.',
          ),
          section(
            'Юридические дела',
            widget.matters.map(matterTile).toList(),
            emptyText: 'Юридических дел с этим контрагентом пока нет.',
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _CountChip(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
