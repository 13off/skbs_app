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
  static const double _desktopListWidth = 1120;

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

  String monthName(int month) {
    const names = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    if (month < 1 || month > names.length) return 'Месяц';
    return names[month - 1];
  }

  String paymentTypeLabel(String? value) {
    switch (value) {
      case 'advance':
        return 'Аванс';
      case 'salary':
        return 'Зарплата';
      case 'fine':
        return 'Штраф';
      case 'other':
        return 'Другая выплата';
      default:
        return 'Выплата';
    }
  }

  String paymentPeriodTitle(int year, int month) {
    return '${monthName(month)} $year';
  }

  String desktopTitle(ExpenseItemData item) {
    if (item.isPayment) return paymentTypeLabel(item.paymentType);
    final value = item.name.trim();
    return value.isEmpty ? 'Расход' : value;
  }

  String mobileTitle(ExpenseItemData item) {
    if (!item.isPayment) return desktopTitle(item);
    final person = item.counterpartyName.trim();
    final type = paymentTypeLabel(item.paymentType);
    return person.isEmpty ? type : '$type · $person';
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
    var draftStart = DateTime(from.year, from.month, from.day);
    var draftEnd = DateTime(to.year, to.month, to.day);
    var editingStart = true;
    final firstAllowed = DateTime(2024);
    final lastAllowed = DateTime.now().add(const Duration(days: 365));

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final activeDate = editingStart ? draftStart : draftEnd;

          return AlertDialog(
            title: const Text('Период расходов'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text('С ${formatDate(draftStart)}'),
                          selected: editingStart,
                          onSelected: (_) {
                            setDialogState(() => editingStart = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: Text('По ${formatDate(draftEnd)}'),
                          selected: !editingStart,
                          onSelected: (_) {
                            setDialogState(() => editingStart = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CalendarDatePicker(
                    key: ValueKey<String>(
                      '${editingStart ? 'start' : 'end'}-${activeDate.toIso8601String()}',
                    ),
                    initialDate: activeDate,
                    firstDate: firstAllowed,
                    lastDate: lastAllowed,
                    onDateChanged: (value) {
                      final clean = DateTime(value.year, value.month, value.day);
                      setDialogState(() {
                        if (editingStart) {
                          draftStart = clean;
                          if (draftEnd.isBefore(draftStart)) {
                            draftEnd = draftStart;
                          }
                          editingStart = false;
                        } else {
                          draftEnd = clean;
                          if (draftStart.isAfter(draftEnd)) {
                            draftStart = draftEnd;
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    DateTimeRange(start: draftStart, end: draftEnd),
                  );
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Применить'),
              ),
            ],
          );
        },
      ),
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

  Future<DateTime?> pickSettlementMonth(DateTime initial) async {
    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var year = initial.year;
        var month = initial.month;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Расчётный период'),
            content: SizedBox(
              width: 430,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Предыдущий год',
                        onPressed: () => setDialogState(() => year -= 1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Следующий год',
                        onPressed: () => setDialogState(() => year += 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(12, (index) {
                      final value = index + 1;
                      return ChoiceChip(
                        label: Text(monthName(value)),
                        selected: month == value,
                        onSelected: (_) =>
                            setDialogState(() => month = value),
                      );
                    }),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, DateTime(year, month, 1)),
                child: const Text('Выбрать'),
              ),
            ],
          ),
        );
      },
    );
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
                      initialValue: categoryId,
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
                      initialValue: objectId,
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

  Future<void> editPayment(ExpenseItemData item) async {
    if (!item.isPayment || item.id.isEmpty) return;

    EditablePaymentData? payment;
    await runBusy(() async {
      payment = await repository.fetchPaymentForEdit(item.id);
    });
    if (!mounted || payment == null) return;

    final source = payment!;
    final amountController = TextEditingController(
      text: source.amount % 1 == 0
          ? source.amount.toInt().toString()
          : source.amount.toStringAsFixed(2),
    );
    final commentController = TextEditingController(text: source.comment);
    var paymentDate = source.paymentDate;
    var settlementMonth = DateTime(source.periodYear, source.periodMonth, 1);
    final allowedTypes = <String>{'advance', 'salary', 'fine', 'other'};
    var paymentType = allowedTypes.contains(source.paymentType)
        ? source.paymentType
        : 'other';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDate() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: paymentDate,
              firstDate: DateTime(2024),
              lastDate: DateTime(2035, 12, 31),
              helpText: 'Дата выплаты',
            );
            if (picked != null) {
              setDialogState(() => paymentDate = picked);
            }
          }

          Future<void> pickPeriod() async {
            final picked = await pickSettlementMonth(settlementMonth);
            if (picked != null) {
              setDialogState(() => settlementMonth = picked);
            }
          }

          return AlertDialog(
            title: const Text('Изменить выплату'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.counterpartyName.trim().isEmpty
                                      ? 'Сотрудник'
                                      : item.counterpartyName.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (item.objectName ?? '').trim().isEmpty
                                      ? 'Объект не указан'
                                      : item.objectName!.trim(),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Сумма, ₽'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentType,
                      decoration: const InputDecoration(labelText: 'Тип выплаты'),
                      items: const [
                        DropdownMenuItem(value: 'advance', child: Text('Аванс')),
                        DropdownMenuItem(
                          value: 'salary',
                          child: Text('Заработная плата'),
                        ),
                        DropdownMenuItem(value: 'fine', child: Text('Штраф')),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Другая выплата'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => paymentType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Дата выплаты'),
                      subtitle: Text(formatDate(paymentDate)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: pickDate,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_note_outlined),
                      title: const Text('Расчётный период'),
                      subtitle: Text(
                        paymentPeriodTitle(
                          settlementMonth.year,
                          settlementMonth.month,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: pickPeriod,
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
                    if (item.attachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Чеки: ${item.attachments.length}. Они сохранятся без изменений.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
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
                onPressed: () {
                  final amount = parseAmount(amountController.text);
                  if (amount <= 0) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Укажи сумму выплаты больше нуля'),
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
        await repository.updatePayment(
          id: source.id,
          employeeId: source.employeeId,
          periodYear: settlementMonth.year,
          periodMonth: settlementMonth.month,
          paymentDate: paymentDate,
          amount: parseAmount(amountController.text),
          paymentType: paymentType,
          comment: commentController.text,
        );
        await load();
      });
      if (mounted && errorText == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выплата изменена')),
        );
      }
    }

    amountController.dispose();
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

  Future<void> deletePayment(ExpenseItemData item) async {
    if (!item.isPayment || item.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выплату?'),
        content: Text(
          '${item.counterpartyName.trim().isEmpty ? 'Выплата' : item.counterpartyName.trim()} — ${formatMoney(item.amount)} от ${formatDate(item.date)}. Запись удалится и из раздела «Выплаты», а прикреплённые чеки будут удалены.',
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
      await repository.deletePayment(item.id);
      await load();
    });
    if (mounted && errorText == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выплата удалена')),
      );
    }
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

  Future<void> handleAction(ExpenseItemData item, String value) async {
    if (value == 'edit') {
      if (item.isPayment) {
        await editPayment(item);
      } else {
        await editExpense(item);
      }
      return;
    }
    if (value == 'delete') {
      if (item.isPayment) {
        await deletePayment(item);
      } else {
        await deleteExpense(item);
      }
    }
  }

  Widget actionMenu(ExpenseItemData item) {
    final hasActions = item.isPayment || item.isEditable;
    return SizedBox(
      width: 40,
      child: hasActions
          ? PopupMenuButton<String>(
              enabled: !busy,
              tooltip: 'Действия',
              onSelected: (value) => handleAction(item, value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 19),
                      SizedBox(width: 10),
                      Text('Изменить'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 19),
                      SizedBox(width: 10),
                      Text('Удалить'),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget receiptStatus(ExpenseItemData item) {
    if (item.attachments.isNotEmpty) {
      final label = item.attachments.length == 1
          ? 'Чек'
          : 'Чеки: ${item.attachments.length}';
      return SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: busy ? null : () => showReceipts(item),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.attachment_rounded, size: 16),
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              'Без чека',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
                spacing: 18,
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 260,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(
                        'expense-category-$selectedCategory-${snapshot.categories.length}',
                      ),
                      initialValue: selectedCategory,
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
                      key: ValueKey(
                        'expense-object-$selectedObject-${snapshot.objects.length}',
                      ),
                      initialValue: selectedObject,
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
                  FilledButton.icon(
                    onPressed: busy ? null : () => editExpense(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить расход'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                snapshot.categories.isEmpty
                    ? 'Статьи расходов настраиваются в панели Разработчика.'
                    : 'Выплаты синхронизированы с разделом «Выплаты»: изменение или удаление здесь меняет исходную запись.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget expenseListHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _desktopListWidth) {
          return const SizedBox.shrink();
        }
        final style = TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.25,
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const SizedBox(width: 42),
              const SizedBox(width: 12),
              SizedBox(width: 86, child: Text('ДАТА', style: style)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: Text('РАСХОД', style: style)),
              const SizedBox(width: 16),
              SizedBox(
                width: 190,
                child: Text('СТАТЬЯ / ОБЪЕКТ', style: style),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 190,
                child: Text('СОТРУДНИК / КОНТРАГЕНТ', style: style),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 112, child: Text('ДОКУМЕНТ', style: style)),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: Text('СУММА', textAlign: TextAlign.right, style: style),
              ),
              const SizedBox(width: 40),
            ],
          ),
        );
      },
    );
  }

  Widget desktopExpenseCard(ExpenseItemData item) {
    final comment = item.comment.trim();
    final objectName = (item.objectName ?? '').trim();
    final responsible = item.counterpartyName.trim();
    return PremiumWorkCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.isPayment
                  ? Icons.payments_outlined
                  : Icons.receipt_long_outlined,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 86,
            child: Text(
              formatDate(item.date),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: desktopTitle(item),
                  child: Text(
                    desktopTitle(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 18,
                  child: comment.isEmpty
                      ? const SizedBox.shrink()
                      : Tooltip(
                          message: comment,
                          child: Text(
                            comment,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.categoryName.trim().isEmpty
                      ? 'Без статьи'
                      : item.categoryName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  objectName.isEmpty ? 'Без объекта' : objectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 190,
            child: Tooltip(
              message: responsible,
              child: Text(
                responsible.isEmpty ? '—' : responsible,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 112, child: receiptStatus(item)),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text(
              formatMoney(item.amount),
              textAlign: TextAlign.right,
              maxLines: 1,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
          actionMenu(item),
        ],
      ),
    );
  }

  Widget mobileExpenseCard(ExpenseItemData item) {
    final objectName = (item.objectName ?? '').trim();
    final responsible = item.counterpartyName.trim();
    final comment = item.comment.trim();
    final meta = <String>[
      formatDate(item.date),
      item.categoryName.trim().isEmpty ? 'Без статьи' : item.categoryName.trim(),
      if (objectName.isNotEmpty) objectName,
      if (!item.isPayment && responsible.isNotEmpty) responsible,
    ];

    return PremiumWorkCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              item.isPayment
                  ? Icons.payments_outlined
                  : Icons.receipt_long_outlined,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mobileTitle(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(
                  meta.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    comment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 9),
                Align(
                  alignment: Alignment.centerLeft,
                  child: receiptStatus(item),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(item.amount),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              actionMenu(item),
            ],
          ),
        ],
      ),
    );
  }

  Widget expenseCard(ExpenseItemData item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _desktopListWidth) {
            return desktopExpenseCard(item);
          }
          return mobileExpenseCard(item);
        },
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
      subtitle: 'Выплаты сотрудникам и другие фактические расходы',
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: busy ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      leading: [filterPanel(), expenseListHeader()],
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
