import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_document_operations_repository.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';

const legalDocumentLifecycleStatuses = <String>[
  'draft',
  'prepared',
  'review',
  'awaiting_signature',
  'signed',
  'active',
  'expired',
  'needs_correction',
  'terminated',
  'archive',
];

String legalDocumentLifecycleTitle(String value) => switch (value) {
      'prepared' => 'Подготовлен',
      'review' => 'На согласовании',
      'awaiting_signature' => 'На подписи',
      'signed' => 'Подписан',
      'active' => 'Действует',
      'expired' => 'Истёк',
      'needs_correction' => 'Требует исправления',
      'terminated' => 'Расторгнут',
      'archive' => 'Архив',
      _ => 'Черновик',
    };

class LegalDocumentCompleteScreen extends StatefulWidget {
  final LegalDocument document;

  const LegalDocumentCompleteScreen({super.key, required this.document});

  @override
  State<LegalDocumentCompleteScreen> createState() =>
      _LegalDocumentCompleteScreenState();
}

class _LegalDocumentCompleteScreenState
    extends State<LegalDocumentCompleteScreen> {
  late LegalDocument document;
  late Future<_LegalDocumentCompleteData> future;
  bool uploading = false;
  bool changingStatus = false;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    future = load();
  }

  Future<_LegalDocumentCompleteData> load() async {
    final values = await Future.wait<dynamic>([
      LegalDocumentOperationsRepository.fetchVersions(document.id),
      LegalDocumentOperationsRepository.fetchEvents(document.id),
    ]);
    return _LegalDocumentCompleteData(
      versions: values[0] as List<LegalDocumentVersion>,
      events: values[1] as List<LegalDocumentEvent>,
    );
  }

  Future<void> refresh() async {
    final fresh = await LegalRepository.fetchDocument(document.id);
    final next = load();
    if (!mounted) return;
    setState(() {
      document = fresh;
      future = next;
    });
    await next;
  }

  String date(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  String dateTime(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    return '${date(local)} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> edit() async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(
        builder: (_) => LegalDocumentEditorScreen(document: document),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> addVersion() async {
    if (uploading) return;
    final file = await LegalDocumentOperationsRepository.pickDocumentFile();
    if (file == null || !mounted) return;
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая версия файла'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Комментарий к версии',
            hintText: 'Например: подписанный оригинал',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Загрузить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null) return;
    setState(() => uploading = true);
    try {
      await LegalDocumentOperationsRepository.uploadVersion(
        documentId: document.id,
        file: file,
        versionLabel: label,
      );
      if (mounted) await refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить версию: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> changeStatus(String status) async {
    if (changingStatus || status == document.status) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить статус документа?'),
        content: Text(
          '${legalDocumentLifecycleTitle(document.status)} → ${legalDocumentLifecycleTitle(status)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => changingStatus = true);
    try {
      await LegalDocumentOperationsRepository.setStatus(
        documentId: document.id,
        status: status,
      );
      if (mounted) await refresh();
    } finally {
      if (mounted) setState(() => changingStatus = false);
    }
  }

  Widget infoCard() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: legalDocumentLifecycleStatuses.contains(document.status)
                ? document.status
                : 'draft',
            decoration: const InputDecoration(
              labelText: 'Статус документа',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: legalDocumentLifecycleStatuses
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(legalDocumentLifecycleTitle(value)),
                  ),
                )
                .toList(),
            onChanged: changingStatus
                ? null
                : (value) {
                    if (value != null) changeStatus(value);
                  },
          ),
          const SizedBox(height: 18),
          line('Тип', document.documentType),
          line('Номер', document.documentNumber),
          line('Дата', date(document.createdOn)),
          line('Подписан', date(document.signedOn)),
          line('Действует с', date(document.validFrom)),
          line('Действует до', date(document.expiresOn)),
          line('Ответственный', document.responsibleName),
          line('Сотрудник', document.employeeName),
          line('Объект', document.objectName),
          line('Контрагент', document.counterpartyName),
          line('Следующий шаг', document.nextAction),
          line('Срок шага', dateTime(document.nextActionDueAt)),
          line('Комментарий', document.comment),
        ],
      ),
    );
  }

  Widget versions(List<LegalDocumentVersion> items) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Файлы и версии',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: uploading ? null : addVersion,
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: const Text('Версия'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('Файл пока не прикреплён')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text('v${item.versionNo}'),
                ),
                title: Text(
                  item.originalName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    'Версия ${item.versionNo}',
                    if (item.versionLabel.isNotEmpty) item.versionLabel,
                    if (item.isPrimary) 'текущая',
                    if (item.createdAt != null) dateTime(item.createdAt),
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => LegalDocumentOperationsRepository.openVersion(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget history(List<LegalDocumentEvent> items) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'История документа',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('История появится после изменений документа')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (item.type) {
                    'created' => Icons.add_circle_outline,
                    'status' => Icons.flag_outlined,
                    'file' => Icons.attach_file_outlined,
                    _ => Icons.edit_note_outlined,
                  },
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    if (item.body.isNotEmpty) item.body,
                    if (item.createdAt != null) dateTime(item.createdAt),
                  ].join(' • '),
                ),
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
        title: const Text('Документ'),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            onPressed: edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_LegalDocumentCompleteData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(child: Text('Не удалось загрузить документ: ${snapshot.error}'));
            }
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return AppPage(
            title: document.title,
            subtitle:
                '${legalDocumentLifecycleTitle(document.status)} • ${document.expiryTitle}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                infoCard(),
                const SizedBox(height: 12),
                versions(data.versions),
                const SizedBox(height: 12),
                history(data.events),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LegalDocumentCompleteData {
  final List<LegalDocumentVersion> versions;
  final List<LegalDocumentEvent> events;

  const _LegalDocumentCompleteData({
    required this.versions,
    required this.events,
  });
}
