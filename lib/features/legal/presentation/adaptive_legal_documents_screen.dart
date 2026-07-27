import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';

class AdaptiveLegalDocumentsScreen extends StatelessWidget {
  final bool attentionOnly;
  final String? initialStatus;

  const AdaptiveLegalDocumentsScreen({
    super.key,
    this.attentionOnly = false,
    this.initialStatus,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return LegalDocumentsScreen(
            attentionOnly: attentionOnly,
            initialStatus: initialStatus,
          );
        }
        return _DesktopLegalDocumentsScreen(
          attentionOnly: attentionOnly,
          initialStatus: initialStatus,
        );
      },
    );
  }
}

class _DesktopLegalDocumentsScreen extends StatefulWidget {
  final bool attentionOnly;
  final String? initialStatus;

  const _DesktopLegalDocumentsScreen({
    required this.attentionOnly,
    required this.initialStatus,
  });

  @override
  State<_DesktopLegalDocumentsScreen> createState() =>
      _DesktopLegalDocumentsScreenState();
}

class _DesktopLegalDocumentsScreenState
    extends State<_DesktopLegalDocumentsScreen> {
  final searchController = TextEditingController();
  late Future<List<LegalDocument>> future;
  StreamSubscription<AppDataChange>? subscription;
  String? status;
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
      CupertinoPageRoute<bool>(
        builder: (_) => LegalDocumentEditorScreen(document: document),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  Future<void> openDetails(LegalDocument document) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => LegalDocumentDetailsScreen(document: document),
      ),
    );
    if (mounted) await refresh();
  }

  Color statusColor(LegalDocument document) {
    if (document.isExpired || document.isActionOverdue) return specialistDanger;
    if (document.needsAttention) return specialistWarning;
    if (document.status == LegalDocumentStatus.signed) {
      return specialistSuccess;
    }
    return specialistMuted;
  }

  String relatedTitle(LegalDocument document) {
    final values = <String>[
      if (document.employeeName.isNotEmpty) document.employeeName,
      if (document.objectName.isNotEmpty) document.objectName,
      if (document.counterpartyName.isNotEmpty) document.counterpartyName,
    ];
    return values.isEmpty ? 'Не привязан' : values.join(' • ');
  }

  Widget filters() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Название, номер, сотрудник, объект или контрагент',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Найти',
                  onPressed: refresh,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => refresh(),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 245,
            child: DropdownButtonFormField<String>(
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
          ),
          const SizedBox(width: 12),
          FilterChip(
            selected: attentionOnly,
            avatar: const Icon(Icons.priority_high_rounded, size: 18),
            label: const Text('Требуют внимания'),
            onSelected: (value) {
              setState(() {
                attentionOnly = value;
                future = load();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget summary(List<LegalDocument> documents) {
    final attention = documents.where((item) => item.needsAttention).length;
    final signed = documents
        .where(
          (item) =>
              item.status == LegalDocumentStatus.signed,
        )
        .length;
    final expiring = documents
        .where((item) => item.isExpired || item.isExpiringSoon)
        .length;

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Summary(
            icon: Icons.folder_copy_outlined,
            label: 'Показано',
            value: '${documents.length}',
          ),
          _Summary(
            icon: Icons.priority_high_rounded,
            label: 'Внимание',
            value: '$attention',
            color: specialistWarning,
          ),
          _Summary(
            icon: Icons.verified_outlined,
            label: 'Подписаны и действуют',
            value: '$signed',
            color: specialistSuccess,
          ),
          _Summary(
            icon: Icons.event_busy_outlined,
            label: 'Сроки',
            value: '$expiring',
            color: expiring > 0 ? specialistDanger : specialistMuted,
          ),
        ],
      ),
    );
  }

  Widget table(List<LegalDocument> documents) {
    return SpecialistDesktopTable(
      minWidth: 1220,
      columns: const [
        SpecialistTableColumn('Документ', flex: 3),
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('Номер', flex: 1),
        SpecialistTableColumn('Связи', flex: 3),
        SpecialistTableColumn('Срок', flex: 2),
        SpecialistTableColumn('Ответственный', flex: 2),
        SpecialistTableColumn('Следующее действие', flex: 3),
      ],
      rows: documents
          .map(
            (document) => SpecialistTableRowData(
              onTap: () => openDetails(document),
              cells: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    specialistCellText(
                      document.title,
                      weight: FontWeight.w900,
                    ),
                    const SizedBox(height: 3),
                    specialistCellText(
                      document.documentType,
                      color: specialistMuted,
                      weight: FontWeight.w600,
                      maxLines: 1,
                    ),
                  ],
                ),
                SpecialistStatusPill(
                  label: document.statusTitle,
                  color: statusColor(document),
                ),
                specialistCellText(
                  document.documentNumber,
                  maxLines: 1,
                ),
                specialistCellText(
                  relatedTitle(document),
                  color: specialistMuted,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    specialistCellText(document.expiryTitle, maxLines: 1),
                    if (document.needsAttention)
                      SpecialistStatusPill(
                        label: 'Проверить',
                        color: statusColor(document),
                      ),
                  ],
                ),
                specialistCellText(
                  document.responsibleName.isEmpty
                      ? 'Не назначен'
                      : document.responsibleName,
                  color: specialistMuted,
                ),
                specialistCellText(
                  document.nextAction.isEmpty
                      ? 'Действие не указано'
                      : document.nextAction,
                  color: specialistMuted,
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LegalDocument>>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[filters(), const SizedBox(height: 16)];
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.description_outlined,
              title: 'Загружаем документы',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить документы',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final documents = snapshot.data ?? const <LegalDocument>[];
          children.add(summary(documents));
          children.add(const SizedBox(height: 16));
          if (documents.isEmpty) {
            children.add(
              const SpecialistMessageCard(
                icon: Icons.search_off_rounded,
                title: 'Документы не найдены',
                description: 'Измените поиск или выбранные фильтры.',
              ),
            );
          } else {
            children.add(table(documents));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-legal-documents',
          title: 'Юридические документы',
          subtitle:
              'Единый реестр договоров, актов, доверенностей и кадровых документов',
          trailing: Wrap(
            spacing: 10,
            children: [
              IconButton.filledTonal(
                tooltip: 'Обновить',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              FilledButton.icon(
                onPressed: () => openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить документ'),
              ),
            ],
          ),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _Summary({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? specialistMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: specialistSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: specialistLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
