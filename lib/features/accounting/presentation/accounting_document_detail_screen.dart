import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/accounting_detail_repository.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';
import 'accounting_workspace_widgets.dart';

class AccountingDocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const AccountingDocumentDetailScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<AccountingDocumentDetailScreen> createState() =>
      _AccountingDocumentDetailScreenState();
}

class _AccountingDocumentDetailScreenState
    extends State<AccountingDocumentDetailScreen> {
  final repository = AccountingDetailRepository();
  late Future<AccountingPrimaryDocument?> future;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<AccountingPrimaryDocument?> load() {
    return repository.fetchDocument(widget.documentId);
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<XFile?> pickFile() async {
    const type = XTypeGroup(
      label: 'Первичные документы',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'xlsx', 'xls', 'csv'],
    );
    return openFile(acceptedTypeGroups: const [type]);
  }

  Future<void> editDocument(AccountingPrimaryDocument document) async {
    final draft = await showDialog<_DocumentEditDraft>(
      context: context,
      builder: (_) => _DocumentEditDialog(document: document),
    );
    if (draft == null) return;
    setState(() => busy = true);
    try {
      await repository.updateDocument(
        documentId: document.id,
        documentType: draft.documentType,
        number: draft.number,
        date: draft.date,
        counterparty: draft.counterparty,
        objectName: draft.objectName,
        amount: draft.amount,
        vatAmount: draft.vatAmount,
        invoiceNumber: draft.invoiceNumber,
        invoiceDate: draft.invoiceDate,
        status: draft.status,
        comment: draft.comment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Документ обновлён')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить документ: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addFile(AccountingPrimaryDocument document) async {
    final file = await pickFile();
    if (file == null) return;
    setState(() => busy = true);
    try {
      await repository.addDocumentFile(
        documentId: document.id,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл добавлен')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось добавить файл: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> replaceFile(
    AccountingPrimaryDocument document,
    AccountingDocumentFile previous,
  ) async {
    final file = await pickFile();
    if (file == null) return;
    setState(() => busy = true);
    try {
      await repository.replaceDocumentFile(
        documentId: document.id,
        previous: previous,
        fileName: file.name,
        bytes: await file.readAsBytes(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл заменён')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось заменить файл: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> deleteFile(AccountingDocumentFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл?'),
        content: Text(file.fileName.isEmpty ? 'Файл будет удалён.' : file.fileName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await repository.deleteDocumentFile(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл удалён')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить файл: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openFile(AccountingDocumentFile file) async {
    try {
      final url = await repository.createDocumentFileSignedUrl(file);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть файл: $error')),
      );
    }
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              title,
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget fileCard(
    AccountingPrimaryDocument document,
    AccountingDocumentFile file,
  ) {
    return PremiumWorkCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName.isEmpty ? 'Файл' : file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  file.contentType,
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Открыть',
            onPressed: busy ? null : () => openFile(file),
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: 'Заменить',
            onPressed: busy ? null : () => replaceFile(document, file),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: busy ? null : () => deleteFile(file),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Бухгалтерский документ'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: busy ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: FutureBuilder<AccountingPrimaryDocument?>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Не удалось загрузить документ: ${snapshot.error}'),
                ),
              );
            }
            final document = snapshot.data;
            if (document == null) {
              return const Center(child: Text('Документ не найден'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                if (busy) const LinearProgressIndicator(),
                if (busy) const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              document.number.isEmpty
                                  ? 'Документ без номера'
                                  : 'Документ № ${document.number}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          AccountingStatusBadge(
                            label: accountingDocStatusLabel(document.status),
                            color: accountingDocStatusColor(document.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      infoRow(
                        'Тип',
                        document.documentType == 'purchase'
                            ? 'Поступление'
                            : 'Реализация',
                      ),
                      infoRow('Дата', accountingDate(document.date)),
                      infoRow('Контрагент', document.counterparty),
                      infoRow('Объект', document.objectName),
                      infoRow('Сумма', accountingMoney(document.amount)),
                      infoRow('НДС', accountingMoney(document.vatAmount)),
                      infoRow('Счёт-фактура', document.invoiceNumber),
                      infoRow(
                        'Дата счёт-фактуры',
                        document.invoiceDate == null
                            ? '—'
                            : accountingDate(document.invoiceDate!),
                      ),
                      infoRow('Комментарий', document.comment),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => editDocument(document),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Редактировать документ'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Файлы · ${document.files.length}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : () => addFile(document),
                            icon: const Icon(Icons.attach_file_rounded),
                            label: const Text('Добавить файл'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (document.files.isEmpty)
                        Text(
                          'Подтверждающие файлы пока не прикреплены.',
                          style: TextStyle(
                            color: AppAdaptivePalette.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ...document.files.map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: fileCard(document, file),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DocumentEditDraft {
  final String documentType;
  final String number;
  final DateTime date;
  final String counterparty;
  final String objectName;
  final double amount;
  final double vatAmount;
  final String invoiceNumber;
  final DateTime? invoiceDate;
  final String status;
  final String comment;

  const _DocumentEditDraft({
    required this.documentType,
    required this.number,
    required this.date,
    required this.counterparty,
    required this.objectName,
    required this.amount,
    required this.vatAmount,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.status,
    required this.comment,
  });
}

class _DocumentEditDialog extends StatefulWidget {
  final AccountingPrimaryDocument document;

  const _DocumentEditDialog({required this.document});

  @override
  State<_DocumentEditDialog> createState() => _DocumentEditDialogState();
}

class _DocumentEditDialogState extends State<_DocumentEditDialog> {
  late final TextEditingController number;
  late final TextEditingController counterparty;
  late final TextEditingController objectName;
  late final TextEditingController amount;
  late final TextEditingController vat;
  late final TextEditingController invoice;
  late final TextEditingController comment;
  late DateTime date;
  DateTime? invoiceDate;
  late String documentType;
  late String status;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    number = TextEditingController(text: doc.number);
    counterparty = TextEditingController(text: doc.counterparty);
    objectName = TextEditingController(text: doc.objectName);
    amount = TextEditingController(text: doc.amount.toStringAsFixed(2));
    vat = TextEditingController(text: doc.vatAmount.toStringAsFixed(2));
    invoice = TextEditingController(text: doc.invoiceNumber);
    comment = TextEditingController(text: doc.comment);
    date = doc.date;
    invoiceDate = doc.invoiceDate;
    documentType = doc.documentType;
    status = doc.status;
  }

  @override
  void dispose() {
    number.dispose();
    counterparty.dispose();
    objectName.dispose();
    amount.dispose();
    vat.dispose();
    invoice.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> chooseDate({required bool invoiceMode}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: invoiceMode ? invoiceDate ?? date : date,
    );
    if (selected == null) return;
    setState(() {
      if (invoiceMode) {
        invoiceDate = selected;
      } else {
        date = selected;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать документ'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: documentType,
                      decoration: const InputDecoration(labelText: 'Тип'),
                      items: const [
                        DropdownMenuItem(
                          value: 'purchase',
                          child: Text('Поступление'),
                        ),
                        DropdownMenuItem(
                          value: 'sale',
                          child: Text('Реализация'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => documentType = value ?? documentType),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Статус'),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Черновик')),
                        DropdownMenuItem(value: 'ready', child: Text('Готов')),
                        DropdownMenuItem(value: 'posted', child: Text('Проведён')),
                        DropdownMenuItem(
                          value: 'attention',
                          child: Text('Требует внимания'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => status = value ?? status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: number,
                      decoration: const InputDecoration(
                        labelText: 'Номер документа',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => chooseDate(invoiceMode: false),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(accountingDate(date)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: counterparty,
                decoration: const InputDecoration(labelText: 'Контрагент'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: objectName,
                decoration: const InputDecoration(labelText: 'Объект'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Сумма'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: vat,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'НДС'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: invoice,
                      decoration: const InputDecoration(
                        labelText: 'Номер счёта-фактуры',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => chooseDate(invoiceMode: true),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      invoiceDate == null
                          ? 'Дата счёт-фактуры'
                          : accountingDate(invoiceDate!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: comment,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final parsedAmount = double.tryParse(amount.text.replaceAll(',', '.'));
            final parsedVat = double.tryParse(vat.text.replaceAll(',', '.')) ?? 0;
            if (parsedAmount == null ||
                parsedAmount <= 0 ||
                counterparty.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _DocumentEditDraft(
                documentType: documentType,
                number: number.text.trim(),
                date: date,
                counterparty: counterparty.text.trim(),
                objectName: objectName.text.trim(),
                amount: parsedAmount,
                vatAmount: parsedVat,
                invoiceNumber: invoice.text.trim(),
                invoiceDate: invoice.text.trim().isEmpty ? null : invoiceDate,
                status: status,
                comment: comment.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
