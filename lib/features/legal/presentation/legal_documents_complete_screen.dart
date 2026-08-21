import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_archive_import_screen.dart';
import 'legal_document_complete_screen.dart';
import 'legal_documents_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalDocumentsCompleteScreen extends StatefulWidget {
  const LegalDocumentsCompleteScreen({super.key});

  @override
  State<LegalDocumentsCompleteScreen> createState() =>
      _LegalDocumentsCompleteScreenState();
}

class _LegalDocumentsCompleteScreenState
    extends State<LegalDocumentsCompleteScreen> {
  late Future<List<LegalDocument>> future;
  final searchController = TextEditingController();
  String category = 'all';
  String? status;
  bool attentionOnly = false;

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

  Future<List<LegalDocument>> load() => LegalRepository.fetchDocuments(
    search: searchController.text,
    status: status,
    attentionOnly: attentionOnly,
  );

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  String group(LegalDocument item) {
    final value = '${item.documentType} ${item.title}'.toLowerCase();
    if (RegExp(
      r'(гпх|договор|контракт|подряд|оказан.*услуг)',
    ).hasMatch(value)) {
      return 'contract';
    }
    if (value.contains('акт')) return 'act';
    if (RegExp(r'(заявлен|соглас|consent|application)').hasMatch(value)) {
      return 'application';
    }
    if (RegExp(
      r'(паспорт|снилс|инн|полис|фото|пропис|регистрац)',
    ).hasMatch(value)) {
      return 'personal';
    }
    return 'other';
  }

  List<LegalDocument> visible(List<LegalDocument> source) {
    if (category == 'all') return source;
    return source.where((item) => group(item) == category).toList();
  }

  Future<void> add() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(builder: (_) => const LegalDocumentEditorScreen()),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> importArchive() async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(builder: (_) => const LegalArchiveImportScreen()),
    );
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Документы',
      subtitle:
          'Один реестр: договоры, акты, заявления, личные и прочие документы',
      headerTrailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: importArchive,
            icon: const Icon(Icons.drive_folder_upload_outlined),
            label: const Text('Импорт'),
          ),
          FilledButton.icon(
            onPressed: add,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Название, номер, сотрудник, объект или контрагент',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: refresh,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                  onSubmitted: (_) => refresh(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      <(String, String)>[
                            ('all', 'Все'),
                            ('contract', 'Договоры'),
                            ('act', 'Акты'),
                            ('application', 'Заявления и согласия'),
                            ('personal', 'Личные'),
                            ('other', 'Прочие'),
                          ]
                          .map(
                            (item) => ChoiceChip(
                              label: Text(item.$2),
                              selected: category == item.$1,
                              onSelected: (_) =>
                                  setState(() => category = item.$1),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Статус',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...legalDocumentLifecycleStatuses.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(legalDocumentLifecycleTitle(value)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      status = value;
                      future = load();
                    });
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Только требующие внимания'),
                  value: attentionOnly,
                  onChanged: (value) {
                    setState(() {
                      attentionOnly = value;
                      future = load();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<LegalDocument>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return PremiumWorkCard(
                    child: Text(
                      'Не удалось загрузить документы: ${snapshot.error}',
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
              final source = snapshot.data!;
              final items = visible(source);
              final attention = source
                  .where((item) => item.needsAttention)
                  .length;
              final missingFileHint = source.isEmpty
                  ? 'Документов пока нет. Добавьте новый или импортируйте существующий архив.'
                  : 'По выбранным фильтрам ничего не найдено.';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumWorkCard(
                    radius: 20,
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Всего: ${source.length}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Показано: ${items.length}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          'Требуют внимания: $attention',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    PremiumWorkCard(
                      radius: 22,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(missingFileHint),
                          if (source.isEmpty) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: importArchive,
                              icon: const Icon(
                                Icons.drive_folder_upload_outlined,
                              ),
                              label: const Text('Импортировать архив'),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PremiumWorkCard(
                          radius: 20,
                          padding: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(switch (group(item)) {
                                'contract' => Icons.handshake_outlined,
                                'act' => Icons.fact_check_outlined,
                                'application' => Icons.edit_document,
                                'personal' => Icons.badge_outlined,
                                _ => Icons.description_outlined,
                              }),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              <String>[
                                legalDocumentLifecycleTitle(item.status),
                                item.expiryTitle,
                                if (item.documentNumber.isNotEmpty)
                                  '№ ${item.documentNumber}',
                                if (item.employeeName.isNotEmpty)
                                  item.employeeName,
                                if (item.objectName.isNotEmpty) item.objectName,
                                if (item.counterpartyName.isNotEmpty)
                                  item.counterpartyName,
                              ].join(' • '),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () async {
                              await Navigator.push<void>(
                                context,
                                AppPageRoute<void>(
                                  builder: (_) => LegalDocumentCompleteScreen(
                                    document: item,
                                  ),
                                ),
                              );
                              if (mounted) await refresh();
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
