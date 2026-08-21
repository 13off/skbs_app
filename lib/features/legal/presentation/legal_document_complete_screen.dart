import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_document_operations_repository.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_documents_screen.dart';
import '../../../navigation/app_page_route.dart';

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
  late Future<_DocumentData> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    document = widget.document;
    future = load();
  }

  Future<_DocumentData> load() async {
    final values = await Future.wait<dynamic>([
      LegalDocumentOperationsRepository.fetchVersions(document.id),
      LegalDocumentOperationsRepository.fetchEvents(document.id),
    ]);
    return _DocumentData(
      versions: values[0] as List<LegalDocumentVersion>,
      events: values[1] as List<LegalDocumentEvent>,
    );
  }

  Future<void> refresh() async {
    final fresh = await LegalRepository.fetchDocument(document.id);
    if (!mounted) return;
    setState(() {
      document = fresh;
      future = load();
    });
  }

  String date(DateTime? value, {bool time = false}) {
    if (value == null) return '—';
    final v = value.toLocal();
    final day =
        '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    if (!time) return day;
    return '$day • ${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
  }

  Widget line(String label, String value) {
    if (value.trim().isEmpty || value == '—') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
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
      AppPageRoute<bool>(
        builder: (_) => LegalDocumentEditorScreen(document: document),
      ),
    );
    if (saved == true && mounted) await refresh();
  }

  Future<void> setStatus(String status) async {
    if (busy || status == document.status) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Изменить статус?'),
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
    if (ok != true) return;
    setState(() => busy = true);
    try {
      await LegalDocumentOperationsRepository.setStatus(
        documentId: document.id,
        status: status,
      );
      if (mounted) await refresh();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addVersion() async {
    if (busy) return;
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
            labelText: 'Комментарий',
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
    setState(() => busy = true);
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
          SnackBar(content: Text('Не удалось загрузить файл: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget info() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue:
                legalDocumentLifecycleStatuses.contains(document.status)
                ? document.status
                : 'draft',
            decoration: const InputDecoration(
              labelText: 'Статус документа',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: legalDocumentLifecycleStatuses
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(legalDocumentLifecycleTitle(status)),
                  ),
                )
                .toList(),
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) setStatus(value);
                  },
          ),
          const SizedBox(height: 16),
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
          line('Срок шага', date(document.nextActionDueAt, time: true)),
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
                onPressed: busy ? null : addVersion,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Версия'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('Файл пока не прикреплён')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text('v${item.versionNo}')),
                title: Text(
                  item.originalName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    if (item.versionLabel.isNotEmpty) item.versionLabel,
                    if (item.isPrimary) 'текущая версия',
                    if (item.createdAt != null)
                      date(item.createdAt, time: true),
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () =>
                    LegalDocumentOperationsRepository.openVersion(item),
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
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('История появится после изменений документа')
          else
            ...items.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  <String>[
                    if (item.body.isNotEmpty) item.body,
                    if (item.createdAt != null)
                      date(item.createdAt, time: true),
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
          IconButton(onPressed: edit, icon: const Icon(Icons.edit_outlined)),
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_DocumentData>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Не удалось загрузить документ: ${snapshot.error}'),
              );
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
                info(),
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

class _DocumentData {
  final List<LegalDocumentVersion> versions;
  final List<LegalDocumentEvent> events;

  const _DocumentData({required this.versions, required this.events});
}
