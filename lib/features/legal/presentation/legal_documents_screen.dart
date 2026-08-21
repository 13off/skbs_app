import 'dart:async';

import 'package:flutter/material.dart';
import 'package:skbs_app/app/app_adaptive_palette.dart';

import '../../../data/app_data_sync.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/object_employee_scope.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import '../../../navigation/app_page_route.dart';

part 'legal_document_details_part.dart';
part 'legal_document_editor_part.dart';

class LegalDocumentsScreen extends StatefulWidget {
  final bool attentionOnly;
  final String? initialStatus;

  const LegalDocumentsScreen({
    super.key,
    this.attentionOnly = false,
    this.initialStatus,
  });

  @override
  State<LegalDocumentsScreen> createState() => _LegalDocumentsScreenState();
}

class _LegalDocumentsScreenState extends State<LegalDocumentsScreen> {
  final searchController = TextEditingController();
  late Future<List<LegalDocument>> future;
  StreamSubscription<AppDataChange>? subscription;
  String? status;
  String category = 'all';
  bool attentionOnly = false;

  @override
  void initState() {
    super.initState();
    status = widget.initialStatus;
    attentionOnly = widget.attentionOnly;
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

  Future<List<LegalDocument>> load() {
    return LegalRepository.fetchDocuments(
      search: searchController.text,
      status: status,
      attentionOnly: attentionOnly,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> openEditor([LegalDocument? document]) async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => LegalDocumentEditorScreen(document: document),
      ),
    );
    if (saved == true && mounted) refresh();
  }

  Future<void> openDetails(LegalDocument document) async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) => LegalDocumentDetailsScreen(document: document),
      ),
    );
    if (mounted) refresh();
  }

  String documentCategory(LegalDocument document) {
    final value = '${document.documentType} ${document.title}'.toLowerCase();
    if (value.contains('договор') ||
        value.contains('контракт') ||
        value.contains('соглашен')) {
      return 'contract';
    }
    if (value.contains('акт')) return 'act';
    return 'other';
  }

  List<LegalDocument> visibleDocuments(List<LegalDocument> source) {
    if (category == 'all') return source;
    return source.where((item) => documentCategory(item) == category).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Документы',
      subtitle: 'Один реестр договоров, актов и других юридических документов',
      headerTrailing: FilledButton.icon(
        onPressed: () => openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
      child: Column(
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по документам',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: refresh,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                  onSubmitted: (_) => refresh(),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Раздел',
                    prefixIcon: Icon(Icons.folder_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text('Все документы'),
                    ),
                    DropdownMenuItem(
                      value: 'contract',
                      child: Text('Договоры'),
                    ),
                    DropdownMenuItem(value: 'act', child: Text('Акты')),
                    DropdownMenuItem(value: 'other', child: Text('Прочие')),
                  ],
                  onChanged: (value) =>
                      setState(() => category = value ?? 'all'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(
                    labelText: 'Статус',
                    prefixIcon: Icon(Icons.filter_alt_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Все статусы'),
                    ),
                    ...LegalDocumentStatus.values.map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(LegalDocumentStatus.title(value)),
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
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        'Не удалось загрузить документы: ${snapshot.error}',
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
              final source = snapshot.data!;
              final documents = visibleDocuments(source);
              if (documents.isEmpty) {
                return PremiumWorkCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          source.isEmpty
                              ? 'Документов пока нет'
                              : 'По выбранному разделу документов нет',
                        ),
                        if (source.isEmpty) ...[
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => openEditor(),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Добавить документ'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: documents.map((document) {
                  final links = <String>[
                    if (document.employeeName.isNotEmpty) document.employeeName,
                    if (document.objectName.isNotEmpty) document.objectName,
                    if (document.counterpartyName.isNotEmpty)
                      document.counterpartyName,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumPressable(
                      onTap: () => openDetails(document),
                      borderRadius: BorderRadius.circular(22),
                      child: PremiumWorkCard(
                        radius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppAdaptivePalette.surfaceSoft,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                documentCategory(document) == 'contract'
                                    ? Icons.handshake_outlined
                                    : documentCategory(document) == 'act'
                                    ? Icons.fact_check_outlined
                                    : Icons.description_outlined,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    document.title,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    [
                                      document.statusTitle,
                                      document.expiryTitle,
                                      if (document.documentNumber.isNotEmpty)
                                        '№ ${document.documentNumber}',
                                    ].join(' • '),
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (links.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      links.join(' • '),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppAdaptivePalette.textFaint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppAdaptivePalette.textFaint,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
