import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/accounting_workbench_repository.dart';
import 'accounting_widgets.dart';
import 'accounting_workspace_widgets.dart';

class AccountingDocumentsScreen extends StatefulWidget {
  const AccountingDocumentsScreen({super.key});

  @override
  State<AccountingDocumentsScreen> createState() => _AccountingDocumentsScreenState();
}

class _AccountingDocumentsScreenState extends State<AccountingDocumentsScreen> {
  final repository = AccountingWorkbenchRepository();
  String view = 'purchase';
  late Future<_DocumentsData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_DocumentsData> load() async {
    final result = await Future.wait<dynamic>([
      repository.fetchDocuments(),
      repository.fetchCounterparties(),
      repository.fetchNomenclature(),
      repository.fetchMaterialMovements(),
    ]);
    return _DocumentsData(
      documents: result[0] as List<AccountingPrimaryDocument>,
      counterparties: result[1] as List<AccountingCounterparty>,
      nomenclature: result[2] as List<AccountingNomenclature>,
      materials: result[3] as List<AccountingMaterialMovement>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> addDocument(String type) async {
    final draft = await showDialog<_DocumentDraft>(
      context: context,
      builder: (_) => _AddDocumentDialog(documentType: type),
    );
    if (draft == null) return;
    try {
      final documentId = await repository.createDocument(
        documentType: type,
        number: draft.number,
        date: draft.date,
        counterparty: draft.counterparty,
        objectName: draft.objectName,
        amount: draft.amount,
        vatAmount: draft.vatAmount,
        invoiceNumber: draft.invoiceNumber,
        invoiceDate: draft.invoiceDate,
        comment: draft.comment,
      );
      if (draft.file != null && documentId.isNotEmpty) {
        await repository.uploadDocumentFile(
          documentId: documentId,
          fileName: draft.file!.name,
          bytes: await draft.file!.readAsBytes(),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            draft.file == null
                ? 'Документ сохранён'
                : 'Документ и файл сохранены',
          ),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить документ: $error')),
      );
    }
  }

  Future<void> addCounterparty() async {
    final draft = await showDialog<_CounterpartyDraft>(
      context: context,
      builder: (_) => const _AddCounterpartyDialog(),
    );
    if (draft == null) return;
    await repository.createCounterparty(
      name: draft.name,
      inn: draft.inn,
      kpp: draft.kpp,
      contractNumber: draft.contractNumber,
    );
    await refresh();
  }

  Future<void> addNomenclature() async {
    final draft = await showDialog<_NomenclatureDraft>(
      context: context,
      builder: (_) => const _AddNomenclatureDialog(),
    );
    if (draft == null) return;
    await repository.createNomenclature(
      name: draft.name,
      kind: draft.kind,
      unit: draft.unit,
      vatRate: draft.vatRate,
      comment: draft.comment,
    );
    await refresh();
  }

  Future<void> addMaterialWriteOff() async {
    final draft = await showDialog<_MaterialDraft>(
      context: context,
      builder: (_) => const _AddMaterialWriteOffDialog(),
    );
    if (draft == null) return;
    await repository.createMaterialWriteOff(
      date: DateTime.now(),
      objectName: draft.objectName,
      materialName: draft.materialName,
      quantity: draft.quantity,
      unit: draft.unit,
      amount: draft.amount,
      documentNumber: draft.documentNumber,
    );
    await refresh();
  }

  Future<void> showDocumentFiles(AccountingPrimaryDocument document) async {
    if (document.files.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          document.number.isEmpty
              ? 'Файлы документа'
              : 'Файлы документа № ${document.number}',
        ),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: document.files
                .map(
                  (file) => ListTile(
                    leading: const Icon(Icons.attach_file_rounded),
                    title: Text(
                      file.fileName.isEmpty ? 'Файл' : file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(file.contentType),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () async {
                      final url = await repository.createDocumentFileSignedUrl(
                        file,
                      );
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget actions() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        FilledButton.icon(
          onPressed: switch (view) {
            'purchase' => () => addDocument('purchase'),
            'sale' => () => addDocument('sale'),
            'counterparties' => addCounterparty,
            'nomenclature' => addNomenclature,
            'materials' => addMaterialWriteOff,
            _ => null,
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(
            switch (view) {
              'purchase' => 'Добавить поступление',
              'sale' => 'Добавить реализацию',
              'counterparties' => 'Добавить контрагента',
              'nomenclature' => 'Добавить позицию',
              'materials' => 'Списать материал',
              _ => 'Добавить',
            },
          ),
        ),
      ],
    );
  }

  Widget documentSummary(List<AccountingPrimaryDocument> rows) {
    final total = rows.fold<double>(0, (sum, e) => sum + e.amount);
    final vat = rows.fold<double>(0, (sum, e) => sum + e.vatAmount);
    final withoutFiles = rows.where((e) => e.files.isEmpty).length;
    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.summarize_outlined,
            label: 'Документов',
            value: '${rows.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.payments_outlined,
            label: 'Сумма',
            value: accountingMoney(total),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.percent_rounded,
            label: 'НДС',
            value: accountingMoney(vat),
            accent: specialistWarning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.attach_file_rounded,
            label: 'Без файла',
            value: '$withoutFiles',
            accent: withoutFiles > 0 ? specialistWarning : specialistSuccess,
          ),
        ),
      ],
    );
  }

  Widget documentsTable(List<AccountingPrimaryDocument> rows) {
    if (rows.isEmpty) {
      return AccountingEmptyState(
        icon: Icons.description_outlined,
        title: view == 'purchase'
            ? 'Поступлений пока нет'
            : 'Документов реализации пока нет',
        description:
            'Здесь будут первичные документы с номером, датой, контрагентом, суммой, НДС и файлами.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 1320,
      columns: const [
        SpecialistTableColumn('Дата', flex: 2),
        SpecialistTableColumn('Номер', flex: 2),
        SpecialistTableColumn('Контрагент', flex: 4),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Сумма', flex: 2),
        SpecialistTableColumn('НДС', flex: 2),
        SpecialistTableColumn('Счёт-фактура', flex: 3),
        SpecialistTableColumn('Файлы', flex: 2),
        SpecialistTableColumn('Статус', flex: 2),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              onTap: row.files.isEmpty ? null : () => showDocumentFiles(row),
              cells: [
                specialistCellText(accountingDate(row.date)),
                specialistCellText(
                  row.number.isEmpty ? '—' : row.number,
                  weight: FontWeight.w900,
                ),
                specialistCellText(row.counterparty),
                specialistCellText(
                  row.objectName.isEmpty ? '—' : row.objectName,
                ),
                specialistCellText(
                  accountingMoney(row.amount),
                  weight: FontWeight.w900,
                ),
                specialistCellText(accountingMoney(row.vatAmount)),
                specialistCellText(
                  row.invoiceNumber.isEmpty
                      ? '—'
                      : '${row.invoiceNumber}${row.invoiceDate == null ? '' : ' • ${accountingDate(row.invoiceDate!)}'}',
                ),
                AccountingStatusBadge(
                  label: row.files.isEmpty
                      ? 'Нет файла'
                      : 'Файлов: ${row.files.length}',
                  color: row.files.isEmpty
                      ? specialistWarning
                      : specialistSuccess,
                  icon: Icons.attach_file_rounded,
                ),
                AccountingStatusBadge(
                  label: accountingDocStatusLabel(row.status),
                  color: accountingDocStatusColor(row.status),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget counterpartiesTable(List<AccountingCounterparty> rows) {
    if (rows.isEmpty) {
      return const AccountingEmptyState(
        icon: Icons.apartment_outlined,
        title: 'Контрагентов пока нет',
        description:
            'Добавьте поставщиков и заказчиков. Здесь будут ИНН, КПП и данные договора.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 1000,
      columns: const [
        SpecialistTableColumn('Контрагент', flex: 5),
        SpecialistTableColumn('ИНН', flex: 2),
        SpecialistTableColumn('КПП', flex: 2),
        SpecialistTableColumn('Договор', flex: 3),
        SpecialistTableColumn('Дата договора', flex: 2),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              cells: [
                specialistCellText(row.name, weight: FontWeight.w900),
                specialistCellText(row.inn.isEmpty ? '—' : row.inn),
                specialistCellText(row.kpp.isEmpty ? '—' : row.kpp),
                specialistCellText(
                  row.contractNumber.isEmpty ? '—' : row.contractNumber,
                ),
                specialistCellText(
                  row.contractDate == null
                      ? '—'
                      : accountingDate(row.contractDate!),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget nomenclatureTable(List<AccountingNomenclature> rows) {
    if (rows.isEmpty) {
      return const AccountingEmptyState(
        icon: Icons.list_alt_outlined,
        title: 'Номенклатура пока пустая',
        description:
            'Добавьте услуги, материалы и товары, которые встречаются в первичных документах.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 900,
      columns: const [
        SpecialistTableColumn('Наименование', flex: 6),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Ед.', flex: 2),
        SpecialistTableColumn('Ставка НДС', flex: 2),
        SpecialistTableColumn('Комментарий', flex: 4),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              cells: [
                specialistCellText(row.name, weight: FontWeight.w900),
                specialistCellText(_nomenclatureKind(row.kind)),
                specialistCellText(row.unit.isEmpty ? '—' : row.unit),
                specialistCellText(
                  row.vatRate == null ? 'Без НДС' : '${row.vatRate!.toStringAsFixed(0)}%',
                ),
                specialistCellText(
                  row.comment.isEmpty ? '—' : row.comment,
                  color: specialistMuted,
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  Widget materialsTable(List<AccountingMaterialMovement> rows) {
    if (rows.isEmpty) {
      return const AccountingEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Списаний материалов пока нет',
        description:
            'Здесь учитываем М-29: объект, материал, количество и сумму списания.',
      );
    }
    return SpecialistDesktopTable(
      minWidth: 1050,
      columns: const [
        SpecialistTableColumn('Дата', flex: 2),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Материал', flex: 5),
        SpecialistTableColumn('Количество', flex: 2),
        SpecialistTableColumn('Ед.', flex: 1),
        SpecialistTableColumn('Сумма', flex: 2),
        SpecialistTableColumn('М-29 / документ', flex: 3),
      ],
      rows: rows
          .map(
            (row) => SpecialistTableRowData(
              cells: [
                specialistCellText(accountingDate(row.date)),
                specialistCellText(row.objectName),
                specialistCellText(row.materialName, weight: FontWeight.w900),
                specialistCellText(row.quantity.toStringAsFixed(2)),
                specialistCellText(row.unit),
                specialistCellText(accountingMoney(row.amount)),
                specialistCellText(
                  row.documentNumber.isEmpty ? '—' : row.documentNumber,
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DocumentsData>(
      future: future,
      builder: (context, snapshot) {
        final children = <Widget>[
          AccountingSectionSwitcher(
            selected: view,
            items: const [
              ('purchase', 'Поступления', Icons.call_received_rounded),
              ('sale', 'Реализация', Icons.call_made_rounded),
              ('counterparties', 'Контрагенты', Icons.apartment_outlined),
              ('nomenclature', 'Номенклатура', Icons.list_alt_outlined),
              ('materials', 'Материалы', Icons.inventory_2_outlined),
            ],
            onChanged: (value) => setState(() => view = value),
          ),
          const SizedBox(height: 16),
        ];

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
              title: 'Не удалось загрузить бухгалтерские документы',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          final data = snapshot.data!;
          if (view == 'purchase' || view == 'sale') {
            final rows = data.documents
                .where((e) => e.documentType == view)
                .toList(growable: false);
            children.add(documentSummary(rows));
            children.add(const SizedBox(height: 16));
            children.add(documentsTable(rows));
          } else if (view == 'counterparties') {
            children.add(counterpartiesTable(data.counterparties));
          } else if (view == 'nomenclature') {
            children.add(nomenclatureTable(data.nomenclature));
          } else {
            children.add(materialsTable(data.materials));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-accounting-documents',
          title: 'Документы и учёт',
          subtitle:
              'Поступления, реализация, контрагенты, номенклатура и списание материалов',
          trailing: actions(),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }

  String _nomenclatureKind(String kind) {
    return switch (kind) {
      'service' => 'Услуга',
      'material' => 'Материал',
      'goods' => 'Товар',
      _ => 'Другое',
    };
  }
}

class _DocumentsData {
  final List<AccountingPrimaryDocument> documents;
  final List<AccountingCounterparty> counterparties;
  final List<AccountingNomenclature> nomenclature;
  final List<AccountingMaterialMovement> materials;

  const _DocumentsData({
    required this.documents,
    required this.counterparties,
    required this.nomenclature,
    required this.materials,
  });
}

class _DocumentDraft {
  final String number;
  final DateTime date;
  final String counterparty;
  final String objectName;
  final double amount;
  final double vatAmount;
  final String invoiceNumber;
  final DateTime? invoiceDate;
  final String comment;
  final XFile? file;

  const _DocumentDraft({
    required this.number,
    required this.date,
    required this.counterparty,
    required this.objectName,
    required this.amount,
    required this.vatAmount,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.comment,
    required this.file,
  });
}

class _AddDocumentDialog extends StatefulWidget {
  final String documentType;

  const _AddDocumentDialog({required this.documentType});

  @override
  State<_AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<_AddDocumentDialog> {
  final number = TextEditingController();
  final counterparty = TextEditingController();
  final objectName = TextEditingController();
  final amount = TextEditingController();
  final vat = TextEditingController();
  final invoice = TextEditingController();
  final comment = TextEditingController();
  DateTime documentDate = DateTime.now();
  DateTime? invoiceDate;
  XFile? file;

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

  Future<void> chooseFile() async {
    const type = XTypeGroup(
      label: 'Первичные документы',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'xlsx', 'xls'],
    );
    final selected = await openFile(acceptedTypeGroups: const [type]);
    if (selected != null) setState(() => file = selected);
  }

  Future<void> chooseDocumentDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: documentDate,
    );
    if (selected != null) setState(() => documentDate = selected);
  }

  Future<void> chooseInvoiceDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDate: invoiceDate ?? documentDate,
    );
    if (selected != null) setState(() => invoiceDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.documentType == 'purchase'
            ? 'Новое поступление'
            : 'Новая реализация',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    onPressed: chooseDocumentDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(accountingDate(documentDate)),
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
                      decoration: const InputDecoration(
                        labelText: 'Сумма документа',
                      ),
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
                    onPressed: chooseInvoiceDate,
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
                decoration: const InputDecoration(labelText: 'Комментарий'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      file == null ? 'Файл не выбран' : file!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: chooseFile,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: const Text('Прикрепить файл'),
                  ),
                ],
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
            final parsedAmount = double.tryParse(
              amount.text.replaceAll(',', '.'),
            );
            final parsedVat =
                double.tryParse(vat.text.replaceAll(',', '.')) ?? 0;
            if (parsedAmount == null ||
                parsedAmount <= 0 ||
                counterparty.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _DocumentDraft(
                number: number.text.trim(),
                date: documentDate,
                counterparty: counterparty.text.trim(),
                objectName: objectName.text.trim(),
                amount: parsedAmount,
                vatAmount: parsedVat,
                invoiceNumber: invoice.text.trim(),
                invoiceDate: invoice.text.trim().isEmpty ? null : invoiceDate,
                comment: comment.text.trim(),
                file: file,
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _CounterpartyDraft {
  final String name;
  final String inn;
  final String kpp;
  final String contractNumber;

  const _CounterpartyDraft({
    required this.name,
    required this.inn,
    required this.kpp,
    required this.contractNumber,
  });
}

class _AddCounterpartyDialog extends StatefulWidget {
  const _AddCounterpartyDialog();

  @override
  State<_AddCounterpartyDialog> createState() => _AddCounterpartyDialogState();
}

class _AddCounterpartyDialogState extends State<_AddCounterpartyDialog> {
  final name = TextEditingController();
  final inn = TextEditingController();
  final kpp = TextEditingController();
  final contract = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    inn.dispose();
    kpp.dispose();
    contract.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новый контрагент'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Наименование'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: inn,
              decoration: const InputDecoration(labelText: 'ИНН'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kpp,
              decoration: const InputDecoration(labelText: 'КПП'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contract,
              decoration: const InputDecoration(labelText: 'Номер договора'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _CounterpartyDraft(
                name: name.text.trim(),
                inn: inn.text.trim(),
                kpp: kpp.text.trim(),
                contractNumber: contract.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

class _NomenclatureDraft {
  final String name;
  final String kind;
  final String unit;
  final double? vatRate;
  final String comment;

  const _NomenclatureDraft({
    required this.name,
    required this.kind,
    required this.unit,
    required this.vatRate,
    required this.comment,
  });
}

class _AddNomenclatureDialog extends StatefulWidget {
  const _AddNomenclatureDialog();

  @override
  State<_AddNomenclatureDialog> createState() => _AddNomenclatureDialogState();
}

class _AddNomenclatureDialogState extends State<_AddNomenclatureDialog> {
  final name = TextEditingController();
  final unit = TextEditingController();
  final vat = TextEditingController();
  final comment = TextEditingController();
  String kind = 'service';

  @override
  void dispose() {
    name.dispose();
    unit.dispose();
    vat.dispose();
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Номенклатура'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Наименование'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Тип'),
              items: const [
                DropdownMenuItem(value: 'service', child: Text('Услуга')),
                DropdownMenuItem(value: 'material', child: Text('Материал')),
                DropdownMenuItem(value: 'goods', child: Text('Товар')),
                DropdownMenuItem(value: 'other', child: Text('Другое')),
              ],
              onChanged: (value) => setState(() => kind = value ?? 'service'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Единица'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: vat,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Ставка НДС, %',
                      hintText: 'пусто = без НДС',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: comment,
              decoration: const InputDecoration(labelText: 'Комментарий'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _NomenclatureDraft(
                name: name.text.trim(),
                kind: kind,
                unit: unit.text.trim(),
                vatRate: vat.text.trim().isEmpty
                    ? null
                    : double.tryParse(vat.text.replaceAll(',', '.')),
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

class _MaterialDraft {
  final String objectName;
  final String materialName;
  final double quantity;
  final String unit;
  final double amount;
  final String documentNumber;

  const _MaterialDraft({
    required this.objectName,
    required this.materialName,
    required this.quantity,
    required this.unit,
    required this.amount,
    required this.documentNumber,
  });
}

class _AddMaterialWriteOffDialog extends StatefulWidget {
  const _AddMaterialWriteOffDialog();

  @override
  State<_AddMaterialWriteOffDialog> createState() =>
      _AddMaterialWriteOffDialogState();
}

class _AddMaterialWriteOffDialogState
    extends State<_AddMaterialWriteOffDialog> {
  final objectName = TextEditingController();
  final materialName = TextEditingController();
  final quantity = TextEditingController();
  final unit = TextEditingController(text: 'шт');
  final amount = TextEditingController();
  final documentNumber = TextEditingController();

  @override
  void dispose() {
    objectName.dispose();
    materialName.dispose();
    quantity.dispose();
    unit.dispose();
    amount.dispose();
    documentNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Списание материала'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: objectName,
              decoration: const InputDecoration(labelText: 'Объект'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: materialName,
              decoration: const InputDecoration(labelText: 'Материал'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantity,
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Единица'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              decoration: const InputDecoration(labelText: 'Сумма'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: documentNumber,
              decoration: const InputDecoration(
                labelText: 'М-29 / номер документа',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final q = double.tryParse(quantity.text.replaceAll(',', '.'));
            final a = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
            if (q == null || q <= 0 || materialName.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              _MaterialDraft(
                objectName: objectName.text.trim(),
                materialName: materialName.text.trim(),
                quantity: q,
                unit: unit.text.trim(),
                amount: a,
                documentNumber: documentNumber.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
