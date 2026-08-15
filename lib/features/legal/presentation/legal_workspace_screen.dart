import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import 'legal_matters_screen.dart';

class LegalWorkspaceScreen extends StatefulWidget {
  const LegalWorkspaceScreen({super.key});

  @override
  State<LegalWorkspaceScreen> createState() => _LegalWorkspaceScreenState();
}

class _LegalWorkspaceScreenState extends State<LegalWorkspaceScreen> {
  late Future<_LegalWorkspacePageData> future;
  StreamSubscription<AppDataChange>? subscription;
  final searchController = TextEditingController();
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

  Future<_LegalWorkspacePageData> load() async {
    final values = await Future.wait<dynamic>([
      LegalWorkspaceRepository.fetchSnapshot(),
      LegalRepository.fetchMatters(),
    ]);
    return _LegalWorkspacePageData(
      workspace: values[0] as LegalWorkspaceSnapshot,
      matters: values[1] as List<LegalMatter>,
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

  String dateText(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String money(double value) {
    final whole = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(whole[i]);
    }
    return '${buffer.toString()} ₽';
  }

  Future<void> openDocument(LegalWorkspaceDocument item) async {
    try {
      if (item.legalDocumentId.isNotEmpty) {
        final document = await LegalRepository.fetchDocument(
          item.legalDocumentId,
        );
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          CupertinoPageRoute<void>(
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть документ: $error')),
      );
    }
  }

  Future<void> openMatter(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => LegalMatterDetailsScreen(
          matter: matter,
          canDecide: false,
        ),
      ),
    );
    if (mounted) await refresh();
  }

  Future<void> quickCreateMatter(String kind) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final label = kind == 'court' ? 'судебное дело' : 'претензию';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(kind == 'court' ? 'Новое судебное дело' : 'Новая претензия'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Суть и основание',
                  alignLabelWithHint: true,
                ),
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
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      titleController.dispose();
      descriptionController.dispose();
      return;
    }
    final rawTitle = titleController.text.trim();
    final description = descriptionController.text.trim();
    titleController.dispose();
    descriptionController.dispose();
    if (rawTitle.length < 2) return;

    final title = kind == 'court' ? '[Суд] $rawTitle' : rawTitle;
    try {
      await LegalRepository.saveMatter(
        matterType: kind == 'court' ? LegalMatterType.dispute : LegalMatterType.claim,
        title: title,
        description: description,
        riskLevel: LegalRiskLevel.medium,
        status: LegalMatterStatus.open,
        requiredActions: '',
        result: '',
        requiresForemanAction: false,
        requiresManagerDecision: false,
        managerQuestion: '',
        decisionStatus: 'none',
        decisionComment: '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Создано $label')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать: $error')),
      );
    }
  }

  Widget metric(String title, String value, IconData icon, {String? subtitle}) {
    return SizedBox(
      width: 220,
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget overview(_LegalWorkspacePageData data) {
    final workspace = data.workspace;
    final openMatters = data.matters
        .where((item) => item.status != LegalMatterStatus.closed && item.status != LegalMatterStatus.resolved)
        .toList();
    final overdue = openMatters.where((item) => item.isOverdue).toList();
    final highRisk = openMatters.where((item) => item.isHighRisk).toList();
    final pendingFines = workspace.recoveries
        .where((item) => item.status == 'pending')
        .toList();
    final court = data.matters.where(isCourtMatter).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            metric('Сотрудники', '${workspace.employees.length}', Icons.groups_2_outlined),
            metric('Объекты', '${workspace.objects.length}', Icons.apartment_outlined),
            metric('Договоры', '${workspace.contracts.length}', Icons.handshake_outlined),
            metric('Акты', '${workspace.acts.length}', Icons.fact_check_outlined),
            metric('Открытые дела', '${openMatters.length}', Icons.work_outline_rounded),
            metric('Судебные дела', '${court.length}', Icons.account_balance_outlined),
            metric('Просрочено', '${overdue.length}', Icons.timer_off_outlined),
            metric('Высокий риск', '${highRisk.length}', Icons.warning_amber_rounded),
            metric('Взыскания ждут', '${pendingFines.length}', Icons.payments_outlined),
          ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Что требует внимания',
          subtitle: 'Сроки, риски и решения руководителя',
        ),
        const SizedBox(height: 8),
        if (overdue.isEmpty && highRisk.isEmpty)
          const _EmptyCard(text: 'Срочных юридических рисков сейчас нет')
        else
          ...<LegalMatter>{...overdue, ...highRisk}.take(8).map(matterTile),
        const SizedBox(height: 18),
        const _SectionTitle(
          title: 'Архив не теряется',
          subtitle: 'Закрытые дела и документы остаются доступны в своих разделах',
        ),
        const SizedBox(height: 8),
        const _EmptyCard(
          icon: Icons.history_rounded,
          text: 'Любое дело, акт, договор или взыскание можно поднять через поиск и связи с сотрудником/объектом.',
        ),
      ],
    );
  }

  Widget employeesTab(_LegalWorkspacePageData data) {
    final items = data.workspace.employees.where((item) {
      return matches('${item.fio} ${item.position} ${item.objectName}');
    }).toList();
    if (items.isEmpty) return const _EmptyList(text: 'Сотрудники не найдены');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(item.fio.trim().isEmpty ? '?' : item.fio.trim()[0].toUpperCase()),
            ),
            title: Text(item.fio, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (item.position.isNotEmpty) item.position,
              if (item.objectName.isNotEmpty) item.objectName,
              '${item.documentsCount} док. • ${item.contractsCount} дог. • ${item.actsCount} акт.',
              if (item.finesCount > 0) 'Взыскания: ${item.finesCount}${item.pendingFinesCount > 0 ? ' (${item.pendingFinesCount} ждут)' : ''}',
            ].join('\n')),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => _LegalEmployeeWorkspaceDetailsScreen(employee: item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget objectsTab(_LegalWorkspacePageData data) {
    final items = data.workspace.objects.where((item) {
      return matches('${item.name} ${item.address}');
    }).toList();
    if (items.isEmpty) return const _EmptyList(text: 'Объекты не найдены');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.apartment_rounded)),
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text([
              if (item.address.isNotEmpty) item.address,
              '${item.employeesCount} сотрудников • ${item.contractsCount} договоров • ${item.actsCount} актов',
              '${item.mattersCount} дел${item.openMattersCount > 0 ? ' • ${item.openMattersCount} открыто' : ''}',
            ].join('\n')),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => _LegalObjectWorkspaceDetailsScreen(object: item),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget documentsTab(List<LegalWorkspaceDocument> source, String emptyText) {
    final items = source.where((item) {
      return matches('${item.title} ${item.documentType} ${item.employeeName} ${item.objectName} ${item.fileName}');
    }).toList();
    if (items.isEmpty) return _EmptyList(text: emptyText);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => documentTile(items[index]),
    );
  }

  Widget documentTile(LegalWorkspaceDocument item) {
    final icon = switch (item.category) {
      'contract' => Icons.handshake_outlined,
      'act' => Icons.fact_check_outlined,
      'explanation' => Icons.edit_note_rounded,
      _ => Icons.description_outlined,
    };
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          if (item.employeeName.isNotEmpty) item.employeeName,
          if (item.objectName.isNotEmpty) item.objectName,
          if (item.documentType.isNotEmpty) item.documentType,
          '${dateText(item.documentDate)}${item.status.isNotEmpty ? ' • ${item.status}' : ''}',
        ].join(' • ')),
        trailing: Icon(item.hasStoredFile || item.legalDocumentId.isNotEmpty ? Icons.open_in_new_rounded : Icons.chevron_right_rounded),
        onTap: () => openDocument(item),
      ),
    );
  }

  bool isCourtMatter(LegalMatter item) {
    final title = item.title.trim().toLowerCase();
    return item.matterType == 'court' ||
        (item.matterType == LegalMatterType.dispute &&
            (title.startsWith('[суд]') || title.contains('судеб')));
  }

  Widget mattersTab(List<LegalMatter> source, {required String emptyText, String? actionKind}) {
    final items = source.where((item) {
      return matches('${item.title} ${item.description} ${item.employeeName} ${item.objectName} ${item.counterpartyName}');
    }).toList();
    return Column(
      children: [
        if (actionKind != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => quickCreateMatter(actionKind),
                icon: const Icon(Icons.add_rounded),
                label: Text(actionKind == 'court' ? 'Судебное дело' : 'Претензия'),
              ),
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? _EmptyList(text: emptyText)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => matterTile(items[index]),
                ),
        ),
      ],
    );
  }

  Widget matterTile(LegalMatter item) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(isCourtMatter(item) ? Icons.account_balance_outlined : Icons.gavel_outlined),
        ),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text([
          item.statusTitle,
          item.riskTitle,
          if (item.employeeName.isNotEmpty) item.employeeName,
          if (item.objectName.isNotEmpty) item.objectName,
          if (item.dueAt != null) 'Срок ${dateText(item.dueAt)}',
        ].join(' • ')),
        trailing: item.isOverdue
            ? const Icon(Icons.priority_high_rounded)
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => openMatter(item),
      ),
    );
  }

  Widget recoveriesTab(_LegalWorkspacePageData data) {
    final items = data.workspace.recoveries.where((item) {
      return matches('${item.employeeName} ${item.objectName} ${item.status}');
    }).toList();
    if (items.isEmpty) return const _EmptyList(text: 'Взысканий пока нет');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ExpansionTile(
            leading: const CircleAvatar(child: Icon(Icons.payments_outlined)),
            title: Text('${item.employeeName} — ${money(item.amount)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${dateText(item.absenceDate)} • ${item.objectName} • ${item.status == 'pending' ? 'Ожидает подтверждения' : 'Подтверждено'}'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [
              if (item.actFilePath.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(item.actFileName.isEmpty ? 'Акт' : item.actFileName),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => LegalWorkspaceRepository.openStoredFile(
                    bucketName: 'absence-fine-acts',
                    storagePath: item.actFilePath,
                  ),
                ),
              if (item.explanationFilePath.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(item.explanationFileName.isEmpty ? 'Объяснительная' : item.explanationFileName),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () => LegalWorkspaceRepository.openStoredFile(
                    bucketName: 'absence-explanations',
                    storagePath: item.explanationFilePath,
                  ),
                ),
              if (item.actFilePath.isEmpty && item.explanationFilePath.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Подтверждающие документы ещё не приложены'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Юрист',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text('Единая база дел, сотрудников, объектов и документов', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
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
                    hintText: 'Поиск по сотрудникам, объектам, делам и документам',
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
              const SizedBox(height: 8),
              const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Обзор'),
                  Tab(text: 'Сотрудники'),
                  Tab(text: 'Объекты'),
                  Tab(text: 'Договоры'),
                  Tab(text: 'Акты'),
                  Tab(text: 'Мои дела'),
                  Tab(text: 'Судебные дела'),
                  Tab(text: 'Претензии'),
                  Tab(text: 'Взыскания'),
                ],
              ),
              Expanded(
                child: FutureBuilder<_LegalWorkspacePageData>(
                  future: future,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorState(error: snapshot.error, onRetry: refresh);
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final data = snapshot.data!;
                    final court = data.matters.where(isCourtMatter).toList();
                    final claims = data.matters.where((item) => item.matterType == LegalMatterType.claim).toList();
                    return TabBarView(
                      children: [
                        overview(data),
                        employeesTab(data),
                        objectsTab(data),
                        documentsTab(data.workspace.contracts, 'Договоры пока не добавлены'),
                        documentsTab(data.workspace.acts, 'Акты пока не добавлены'),
                        mattersTab(data.matters, emptyText: 'Юридических дел пока нет'),
                        mattersTab(court, emptyText: 'Судебных дел пока нет', actionKind: 'court'),
                        mattersTab(claims, emptyText: 'Претензий пока нет', actionKind: 'claim'),
                        recoveriesTab(data),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalWorkspacePageData {
  final LegalWorkspaceSnapshot workspace;
  final List<LegalMatter> matters;

  const _LegalWorkspacePageData({required this.workspace, required this.matters});
}

class _LegalEmployeeWorkspaceDetailsScreen extends StatefulWidget {
  final LegalWorkspaceEmployee employee;

  const _LegalEmployeeWorkspaceDetailsScreen({required this.employee});

  @override
  State<_LegalEmployeeWorkspaceDetailsScreen> createState() => _LegalEmployeeWorkspaceDetailsScreenState();
}

class _LegalEmployeeWorkspaceDetailsScreenState extends State<_LegalEmployeeWorkspaceDetailsScreen> {
  late Future<_LinkedLegalData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_LinkedLegalData> load() async {
    final values = await Future.wait<dynamic>([
      LegalWorkspaceRepository.fetchDocuments(employeeId: widget.employee.id),
      LegalWorkspaceRepository.fetchRecoveries(),
      LegalRepository.fetchMatters(),
    ]);
    return _LinkedLegalData(
      documents: values[0] as List<LegalWorkspaceDocument>,
      recoveries: (values[1] as List<LegalWorkspaceRecovery>).where((item) => item.employeeId == widget.employee.id).toList(),
      matters: (values[2] as List<LegalMatter>).where((item) => item.employeeId == widget.employee.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employee = widget.employee;
    return Scaffold(
      appBar: AppBar(title: Text(employee.fio)),
      body: FutureBuilder<_LinkedLegalData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(employee.fio, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (employee.position.isNotEmpty) Text(employee.position),
                    if (employee.objectName.isNotEmpty) Text(employee.objectName),
                    const SizedBox(height: 12),
                    Text('${employee.documentsCount} документов • ${employee.contractsCount} договоров • ${employee.actsCount} актов • ${employee.finesCount} взысканий'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Все связанные документы', subtitle: 'Договоры, акты, кадровые документы и объяснительные'),
              const SizedBox(height: 8),
              if (data.documents.isEmpty)
                const _EmptyCard(text: 'Документы сотрудника пока не загружены')
              else
                ...data.documents.map((item) => _LinkedDocumentCard(item: item)),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Юридические дела'),
              const SizedBox(height: 8),
              if (data.matters.isEmpty)
                const _EmptyCard(text: 'Связанных юридических дел нет')
              else
                ...data.matters.map((item) => _LinkedMatterCard(matter: item)),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Взыскания и невыходы'),
              const SizedBox(height: 8),
              if (data.recoveries.isEmpty)
                const _EmptyCard(text: 'Взысканий нет')
              else
                ...data.recoveries.map((item) => _RecoverySummaryCard(item: item)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _LegalObjectWorkspaceDetailsScreen extends StatefulWidget {
  final LegalWorkspaceObject object;

  const _LegalObjectWorkspaceDetailsScreen({required this.object});

  @override
  State<_LegalObjectWorkspaceDetailsScreen> createState() => _LegalObjectWorkspaceDetailsScreenState();
}

class _LegalObjectWorkspaceDetailsScreenState extends State<_LegalObjectWorkspaceDetailsScreen> {
  late Future<_LinkedLegalData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_LinkedLegalData> load() async {
    final values = await Future.wait<dynamic>([
      LegalWorkspaceRepository.fetchDocuments(objectId: widget.object.id),
      LegalWorkspaceRepository.fetchRecoveries(),
      LegalRepository.fetchMatters(),
    ]);
    return _LinkedLegalData(
      documents: values[0] as List<LegalWorkspaceDocument>,
      recoveries: (values[1] as List<LegalWorkspaceRecovery>).where((item) => item.objectId == widget.object.id).toList(),
      matters: (values[2] as List<LegalMatter>).where((item) => item.objectId == widget.object.id).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final object = widget.object;
    return Scaffold(
      appBar: AppBar(title: Text(object.name)),
      body: FutureBuilder<_LinkedLegalData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(object.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (object.address.isNotEmpty) Text(object.address),
                    const SizedBox(height: 12),
                    Text('${object.employeesCount} сотрудников • ${object.contractsCount} договоров • ${object.actsCount} актов • ${object.openMattersCount} открытых дел'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Документы объекта', subtitle: 'Договоры, акты и связанные документы'),
              const SizedBox(height: 8),
              if (data.documents.isEmpty)
                const _EmptyCard(text: 'Документы объекта пока не добавлены')
              else
                ...data.documents.map((item) => _LinkedDocumentCard(item: item)),
              const SizedBox(height: 18),
              const _SectionTitle(title: 'Дела и риски'),
              const SizedBox(height: 8),
              if (data.matters.isEmpty)
                const _EmptyCard(text: 'Связанных юридических дел нет')
              else
                ...data.matters.map((item) => _LinkedMatterCard(matter: item)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}

class _LinkedLegalData {
  final List<LegalWorkspaceDocument> documents;
  final List<LegalWorkspaceRecovery> recoveries;
  final List<LegalMatter> matters;

  const _LinkedLegalData({required this.documents, required this.recoveries, required this.matters});
}

class _LinkedDocumentCard extends StatelessWidget {
  final LegalWorkspaceDocument item;

  const _LinkedDocumentCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text(item.title),
        subtitle: Text([if (item.documentType.isNotEmpty) item.documentType, if (item.status.isNotEmpty) item.status, if (item.fileName.isNotEmpty) item.fileName].join(' • ')),
        trailing: item.hasStoredFile ? const Icon(Icons.open_in_new_rounded) : null,
        onTap: !item.hasStoredFile
            ? null
            : () => LegalWorkspaceRepository.openStoredFile(bucketName: item.bucketName, storagePath: item.storagePath),
      ),
    );
  }
}

class _LinkedMatterCard extends StatelessWidget {
  final LegalMatter matter;

  const _LinkedMatterCard({required this.matter});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.gavel_outlined),
        title: Text(matter.title),
        subtitle: Text('${matter.statusTitle} • ${matter.riskTitle}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.push<void>(
          context,
          CupertinoPageRoute<void>(
            builder: (_) => LegalMatterDetailsScreen(matter: matter, canDecide: false),
          ),
        ),
      ),
    );
  }
}

class _RecoverySummaryCard extends StatelessWidget {
  final LegalWorkspaceRecovery item;

  const _RecoverySummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final day = item.absenceDate;
    final date = '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text('${item.amount.round()} ₽ • $date'),
        subtitle: Text(item.status == 'pending' ? 'Ожидает подтверждения' : 'Подтверждено'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  final IconData icon;

  const _EmptyCard({required this.text, this.icon = Icons.check_circle_outline_rounded});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String text;

  const _EmptyList({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_outlined, size: 42),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text('Не удалось загрузить юридическую платформу\n$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}