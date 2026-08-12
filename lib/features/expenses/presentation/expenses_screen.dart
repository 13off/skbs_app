import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/expense_repository.dart';

class ExpensesScreen extends StatefulWidget {
  final String? selectedObjectName;

  const ExpensesScreen({super.key, this.selectedObjectName});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  static const String _allCategories = '__all__';
  static const String _paymentsCategory = '__payments__';
  static const String _uncategorized = '__uncategorized__';
  static const String _allObjects = '__all__';

  final ExpenseRepository repository = ExpenseRepository();

  late DateTime from;
  late DateTime to;
  bool loading = true;
  bool busy = false;
  String? errorText;
  ExpensesSnapshot snapshot = const ExpensesSnapshot(
    categories: [],
    objects: [],
    rows: [],
  );
  String selectedCategory = _allCategories;
  String selectedObject = _allObjects;
  bool preferredObjectApplied = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    from = DateTime(now.year, now.month, 1);
    to = DateTime(now.year, now.month + 1, 0);
    load();
  }

  @override
  void didUpdateWidget(covariant ExpensesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      preferredObjectApplied = false;
      selectedObject = _allObjects;
      load();
    }
  }

  String readableError(Object error) {
    final raw = error.toString();
    final match = RegExp(r'message:\s*([^,}]+)').firstMatch(raw);
    return match?.group(1)?.trim() ??
        raw.replaceFirst('PostgrestException(', '').replaceAll(')', '');
  }

  String formatDate(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}.'
        '${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  String formatMoney(double value) {
    final rounded = value.round();
    final raw = rounded.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(raw[i]);
    }
    return '${buffer.toString()} ₽';
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }
    try {
      final data = await repository.fetchSnapshot(from: from, to: to);
      if (!mounted) return;
      setState(() {
        snapshot = data;
        loading = false;
        if (!preferredObjectApplied) {
          preferredObjectApplied = true;
          final preferred = widget.selectedObjectName?.trim().toLowerCase();
          if (preferred != null && preferred.isNotEmpty) {
            for (final object in data.objects) {
              if (object.name.trim().toLowerCase() == preferred) {
                selectedObject = object.id;
                break;
              }
            }
          }
        }
        if (selectedObject != _allObjects &&
            !data.objects.any((item) => item.id == selectedObject)) {
          selectedObject = _allObjects;
        }
        if (selectedCategory != _allCategories &&
            selectedCategory != _paymentsCategory &&
            selectedCategory != _uncategorized &&
            !data.categories.any((item) => item.id == selectedCategory)) {
          selectedCategory = _allCategories;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = 'Не удалось загрузить расходы: ${readableError(error)}';
      });
    }
  }

  List<ExpenseItemData> get filteredRows {
    return snapshot.rows.where((item) {
      final categoryOk = switch (selectedCategory) {
        _allCategories => true,
        _paymentsCategory => item.isPayment,
        _uncategorized => !item.isPayment && item.categoryId == null,
        _ => !item.isPayment && item.categoryId == selectedCategory,
      };
      final objectOk =
          selectedObject == _allObjects || item.objectId == selectedObject;
      return categoryOk && objectOk;
    }).toList(growable: false);
  }

  Future<void> choosePeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'Период расходов',
      saveText: 'Применить',
    );
    if (picked == null || !mounted) return;
    setState(() {
      from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
    await load();
  }

  Future<void> runBusy(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      errorText = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = readableError(error));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${readableError(error)}')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double parseAmount(String raw) {
    return double.tryParse(
          raw.trim().replaceAll(' ', '').replaceAll(',', '.'),
        ) ??
        0;
  }

  Future<List<XFile>> pickReceipts() async {
    return openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Чеки',
          extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        ),
      ],
    );
  }

  Future<void> uploadPendingReceipts({
    required String expenseId,
    required List<XFile> files,
  }) async {
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
        throw StateError('Файл ${file.name} больше 20 МБ');
      }
      await repository.uploadReceipt(
        expenseId: expenseId,
        fileName: file.name,
        bytes: bytes,
        contentType: repository.contentTypeForFileName(file.name),
      );
    }
  }

  Future<void> editExpense([ExpenseItemData? initial]) async {
    if (initial?.isPayment == true) return;
    final nameController = TextEditingController(text: initial?.name ?? '');
    final amountController = TextEditingController(
      text: initial == null
          ? ''
          : (initial.amount % 1 == 0
              ? initial.amount.toInt().toString()
              : initial.amount.toStringAsFixed(2)),
    );
    final counterpartyController = TextEditingController(
      text: initial?.counterpartyName ?? '',
    );
    final commentController = TextEditingController(text: initial?.comment ?? '');
    var date = initial?.date ?? DateTime.now();
    var categoryId = initial?.categoryId ?? '';
    var objectId = initial?.objectId ?? '';
    var pendingReceipts = <XFile>[];
    if (!snapshot.categories.any((item) => item.id == categoryId)) {
      categoryId = '';
    }
    if (!snapshot.objects.any((item) => item.id == objectId)) objectId = '';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2024),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              helpText: 'Дата расхода',
            );
            if (picked != null) setDialogState(() => date = picked);
          }

          Future<void> addReceipts() async {
            final picked = await pickReceipts();
            if (picked.isEmpty) return;
            setDialogState(() {
              pendingReceipts = [...pendingReceipts, ...picked];
            });
          }

          return AlertDialog(
            title: Text(initial == null ? 'Добавить расход' : 'Изменить расход'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например, аренда инструмента',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Статья расходов',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Без статьи'),
                        ),
                        ...snapshot.categories.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => categoryId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: objectId,
                      decoration: const InputDecoration(labelText: 'Объект'),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Без объекта'),
                        ),
                        ...snapshot.objects.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.isActive ? item.name : '${item.name} · архив',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => objectId = value ?? ''),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: counterpartyController,
                      decoration: const InputDecoration(
                        labelText: 'Кто оплатил / контрагент',
                        hintText: 'Например, Одинцев И. А. или ООО «Поставщик»',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Дата'),
                      subtitle: Text(formatDate(date)),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: pickDate,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: commentController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий',
                        hintText: 'Необязательно',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: addReceipts,
                        icon: const Icon(Icons.attach_file_rounded),
                        label: const Text('Прикрепить чек'),
                      ),
                    ),
                    if ((initial?.attachments.length ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Уже прикреплено: ${initial!.attachments.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    if (pendingReceipts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...List.generate(pendingReceipts.length, (index) {
                        final file = pendingReceipts[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            tooltip: 'Убрать',
                            onPressed: () => setDialogState(() {
                              pendingReceipts = [...pendingReceipts]
                                ..removeAt(index);
                            }),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        );
                      }),
                    ],
                    if (snapshot.categories.isEmpty) ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Статьи расходов добавляются в панели Разработчика.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
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
                onPressed: busy
                    ? null
                    : () {
                        final name = nameController.text.trim();
                        final amount = parseAmount(amountController.text);
                        if (name.isEmpty || amount <= 0) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Укажи название и сумму больше нуля'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, true);
                      },
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      await runBusy(() async {
        final amount = parseAmount(amountController.text);
        String expenseId;
        if (initial == null) {
          final created = await repository.createExpense(
            name: nameController.text,
            amount: amount,
            date: date,
            categoryId: categoryId.isEmpty ? null : categoryId,
            objectId: objectId.isEmpty ? null : objectId,
            counterpartyName: counterpartyController.text,
            comment: commentController.text,
          );
          expenseId = created.id;
        } else {
          expenseId = initial.id;
          await repository.updateExpense(
            id: initial.id,
            name: nameController.text,
            amount: amount,
            date: date,
            categoryId: categoryId.isEmpty ? null : categoryId,
            objectId: objectId.isEmpty ? null : objectId,
            counterpartyName: counterpartyController.text,
            comment: commentController.text,
          );
        }
        if (expenseId.isEmpty) throw StateError('Не удалось создать расход');
        await uploadPendingReceipts(
          expenseId: expenseId,
          files: pendingReceipts,
        );
        await load();
      });
    }

    nameController.dispose();
    amountController.dispose();
    counterpartyController.dispose();
    commentController.dispose();
  }

  Future<void> deleteExpense(ExpenseItemData item) async {
    if (!item.isEditable || item.isPayment) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить расход?'),
        content: Text(
          '«${item.name}» на ${formatMoney(item.amount)} будет удалён вместе с прикреплёнными чеками.',
        ),
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
    await runBusy(() async {
      await repository.deleteExpense(item.id);
      await load();
    });
  }

  Future<void> openReceipt(ExpenseAttachmentData receipt) async {
    await runBusy(() async {
      final rawUrl = await repository.createReceiptSignedUrl(receipt);
      final uri = Uri.tryParse(rawUrl);
      if (uri == null || !await launchUrl(uri)) {
        throw StateError('Не удалось открыть чек');
      }
    });
  }

  Future<void> deleteReceipt(
    BuildContext sheetContext,
    ExpenseAttachmentData receipt,
  ) async {
    if (!receipt.isEditable) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить чек?'),
        content: Text('Файл «${receipt.fileName}» будет удалён.'),
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
    await runBusy(() async {
      await repository.deleteReceipt(receipt);
      if (sheetContext.mounted) Navigator.pop(sheetContext);
      await load();
    });
  }

  Future<void> showReceipts(ExpenseItemData item) async {
    if (item.attachments.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                item.isPayment ? 'Чеки выплаты' : 'Чеки расхода',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...item.attachments.map(
                (receipt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    receipt.contentType == 'application/pdf'
                        ? Icons.picture_as_pdf_outlined
                        : Icons.image_outlined,
                  ),
                  title: Text(
                    receipt.fileName.isEmpty ? 'Чек' : receipt.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Нажми, чтобы открыть'),
                  onTap: busy ? null : () => openReceipt(receipt),
                  trailing: receipt.isEditable
                      ? IconButton(
                          tooltip: 'Удалить чек',
                          onPressed: busy
                              ? null
                              : () => deleteReceipt(sheetContext, receipt),
                          icon: const Icon(Icons.delete_outline_rounded),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget filterPanel() {
    final rows = filteredRows;
    final total = rows.fold<double>(0, (sum, item) => sum + item.amount);
    final payments = rows
        .where((item) => item.isPayment)
        .fold<double>(0, (sum, item) => sum + item.amount);
    final manual = total - payments;
    final withoutReceipt = rows.where((item) => item.attachments.isEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatMoney(total),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Всего за ${formatDate(from)} — ${formatDate(to)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Выплаты: ${formatMoney(payments)}'),
                  Text('Другие расходы: ${formatMoney(manual)}'),
                  Text('Операций: ${rows.length}'),
                  Text('Без чека: $withoutReceipt'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Статья расходов',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allCategories,
                          child: Text('Все статьи'),
                        ),
                        const DropdownMenuItem(
                          value: _paymentsCategory,
                          child: Text('Выплаты сотрудникам'),
                        ),
                        const DropdownMenuItem(
                          value: _uncategorized,
                          child: Text('Без статьи'),
                        ),
                        ...snapshot.categories.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedCategory = value);
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      value: selectedObject,
                      decoration: const InputDecoration(
                        labelText: 'Объект',
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allObjects,
                          child: Text('Все объекты'),
                        ),
                        ...snapshot.objects.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.isActive ? item.name : '${item.name} · архив',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => selectedObject = value);
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: choosePeriod,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text('${formatDate(from)} — ${formatDate(to)}'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      snapshot.categories.isEmpty
                          ? 'Статьи расходов настраиваются в панели Разработчика.'
                          : 'Выплаты подтягиваются автоматически и не дублируются.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: busy ? null : () => editExpense(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить расход'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          PremiumWorkCard(
            radius: 22,
            padding: const EdgeInsets.all(14),
            child: Text(
              errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 14),
      ],
    );
  }

  Widget expenseCard(ExpenseItemData item) {
    final subtitleParts = <String>[
      formatDate(item.date),
      item.categoryName,
      if ((item.objectName ?? '').trim().isNotEmpty) item.objectName!.trim(),
      if (item.counterpartyName.trim().isNotEmpty) item.counterpartyName.trim(),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                item.isPayment
                    ? Icons.payments_outlined
                    : Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatMoney(item.amount),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (item.comment.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.comment.trim()),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (item.isPayment)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('Выплата'),
                        ),
                      if (item.attachments.isNotEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.attachment_rounded, size: 17),
                          label: Text(
                            item.attachments.length == 1
                                ? 'Чек'
                                : 'Чеки: ${item.attachments.length}',
                          ),
                          onPressed: busy ? null : () => showReceipts(item),
                        )
                      else
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.warning_amber_rounded, size: 17),
                          label: Text('Без чека'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (item.isEditable && !item.isPayment)
              PopupMenuButton<String>(
                enabled: !busy,
                onSelected: (value) {
                  if (value == 'edit') editExpense(item);
                  if (value == 'delete') deleteExpense(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = filteredRows;
    if (loading) {
      return const AppPage(
        title: 'Расходы',
        subtitle: 'Контроль расходов компании',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 64),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppLazyPage(
      title: 'Расходы',
      subtitle: 'Выплаты сотрудникам и ручные расходы в одном месте',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      leading: [filterPanel()],
      itemCount: rows.length,
      itemBuilder: (context, index) => expenseCard(rows[index]),
      trailing: rows.isEmpty
          ? [
              PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.all(20),
                child: const Text(
                  'За выбранный период и фильтры расходов нет.',
                  textAlign: TextAlign.center,
                ),
              ),
            ]
          : const [],
    );
  }
}
