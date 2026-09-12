import 'package:flutter/material.dart';
import 'package:skbs_app/widgets/app_input_formatters.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/expense_repository.dart';

class ExpensesSettingsScreen extends StatefulWidget {
  const ExpensesSettingsScreen({super.key});

  @override
  State<ExpensesSettingsScreen> createState() => _ExpensesSettingsScreenState();
}

class _ExpensesSettingsScreenState extends State<ExpensesSettingsScreen> {
  static const Map<String, String> counterpartyTypeLabels = {
    'legal_entity': 'ООО / юрлицо',
    'individual_entrepreneur': 'ИП',
    'self_employed': 'Самозанятый',
    'individual': 'Физлицо',
    'other': 'Другое',
  };

  final ExpenseRepository repository = ExpenseRepository();

  bool loading = true;
  bool busy = false;
  String? errorText;
  int section = 0;
  List<ExpenseCategoryData> categories = const [];
  List<ExpenseCounterpartyData> counterparties = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  String readableError(Object error) {
    final raw = error.toString();
    if (raw.toLowerCase().contains('duplicate key')) {
      return 'Запись с таким названием уже существует.';
    }
    final match = RegExp(r'message:\s*([^,}]+)').firstMatch(raw);
    return match?.group(1)?.trim() ??
        raw.replaceFirst('PostgrestException(', '').replaceAll(')', '');
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorText = null;
      });
    }
    try {
      final results = await Future.wait<dynamic>([
        repository.fetchCategories(),
        repository.fetchCounterparties(),
      ]);
      if (!mounted) return;
      setState(() {
        categories = results[0] as List<ExpenseCategoryData>;
        counterparties = results[1] as List<ExpenseCounterpartyData>;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = readableError(error);
      });
    }
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
      final text = readableError(error);
      setState(() => errorText = text);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> editCategory([ExpenseCategoryData? initial]) async {
    final controller = TextEditingController(text: initial?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          initial == null ? 'Добавить статью расходов' : 'Изменить статью',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: AppInputFormatters.sentences,
          decoration: const InputDecoration(
            labelText: 'Название статьи',
            hintText: 'Например, Проживание',
          ),
          onSubmitted: (value) {
            final clean = value.trim();
            if (clean.isNotEmpty) Navigator.pop(dialogContext, clean);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final clean = controller.text.trim();
              if (clean.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Укажи название статьи')),
                );
                return;
              }
              Navigator.pop(dialogContext, clean);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    final duplicate = categories.any(
      (item) =>
          item.id != initial?.id &&
          item.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (duplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Такая статья расходов уже есть.')),
      );
      return;
    }

    await runBusy(() async {
      if (initial == null) {
        await repository.createCategory(name);
      } else {
        await repository.updateCategory(initial.id, name);
      }
      await load();
    });
  }

  Future<void> deleteCategory(ExpenseCategoryData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить статью расходов?'),
        content: Text(
          '«${item.name}» исчезнет из справочника. Уже сохранённые расходы не удалятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runBusy(() async {
      await repository.deleteCategory(item.id);
      await load();
    });
  }

  Future<void> editCounterparty([ExpenseCounterpartyData? initial]) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final innController = TextEditingController(text: initial?.inn ?? '');
    final kppController = TextEditingController(text: initial?.kpp ?? '');
    var type = counterpartyTypeLabels.containsKey(initial?.type)
        ? initial!.type
        : 'legal_entity';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            initial == null ? 'Добавить контрагента' : 'Изменить контрагента',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: counterpartyTypeLabels.entries
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: AppInputFormatters.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Название / ФИО',
                      hintText: 'Например, ООО «СтройСнаб» или Иванов И. И.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: innController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ИНН',
                      hintText: 'Необязательно',
                    ),
                  ),
                  if (type == 'legal_entity') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: kppController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'КПП',
                        hintText: 'Необязательно',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Укажи название или ФИО')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, <String, String>{
                  'name': name,
                  'type': type,
                  'inn': innController.text.trim(),
                  'kpp': type == 'legal_entity'
                      ? kppController.text.trim()
                      : '',
                });
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    innController.dispose();
    kppController.dispose();
    if (result == null) return;

    final name = result['name'] ?? '';
    final duplicate = counterparties.any(
      (item) =>
          item.id != initial?.id &&
          item.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (duplicate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Такой контрагент уже есть.')),
      );
      return;
    }

    await runBusy(() async {
      if (initial == null) {
        await repository.createCounterparty(
          name: name,
          type: result['type'] ?? 'other',
          inn: result['inn'] ?? '',
          kpp: result['kpp'] ?? '',
        );
      } else {
        await repository.updateCounterparty(
          id: initial.id,
          name: name,
          type: result['type'] ?? 'other',
          inn: result['inn'] ?? '',
          kpp: result['kpp'] ?? '',
        );
      }
      await load();
    });
  }

  Future<void> deleteCounterparty(ExpenseCounterpartyData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить контрагента?'),
        content: Text(
          '«${item.name}» исчезнет из справочника. Название в уже сохранённых расходах и документах останется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await runBusy(() async {
      await repository.deleteCounterparty(item.id);
      await load();
    });
  }

  Widget categorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Статьи расходов',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text('Создавай свои статьи, переименовывай и удаляй ненужные.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => editCategory(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(20),
            child: Text('Статей расходов пока нет.', textAlign: TextAlign.center),
          )
        else
          ...categories.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.sell_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) {
                        if (value == 'edit') editCategory(item);
                        if (value == 'delete') deleteCategory(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Изменить')),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget counterpartySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Контрагенты',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text('ООО, ИП, самозанятые и физлица — один общий справочник.'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: busy ? null : () => editCounterparty(),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Добавить'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (counterparties.isEmpty)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(20),
            child: Text('Контрагентов пока нет.', textAlign: TextAlign.center),
          )
        else
          ...counterparties.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PremiumWorkCard(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    const Icon(Icons.handshake_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              counterpartyTypeLabels[item.type] ?? 'Другое',
                              if (item.inn.trim().isNotEmpty) 'ИНН ${item.inn.trim()}',
                              if (item.kpp.trim().isNotEmpty) 'КПП ${item.kpp.trim()}',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      onSelected: (value) {
                        if (value == 'edit') editCounterparty(item);
                        if (value == 'delete') deleteCounterparty(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Изменить')),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Настройки расходов',
      subtitle: 'Конструктор статей и справочник контрагентов',
      showBackButton: true,
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busy ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(
                        value: 0,
                        icon: Icon(Icons.sell_outlined),
                        label: Text('Статьи расходов'),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon: Icon(Icons.handshake_outlined),
                        label: Text('Контрагенты'),
                      ),
                    ],
                    selected: <int>{section},
                    onSelectionChanged: busy
                        ? null
                        : (value) => setState(() => section = value.first),
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
                if (section == 0) categorySection() else counterpartySection(),
              ],
            ),
    );
  }
}
