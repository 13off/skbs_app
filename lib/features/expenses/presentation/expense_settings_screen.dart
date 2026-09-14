import 'package:flutter/material.dart';

import '../../../widgets/app_input_formatters.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/expense_repository.dart';

class ExpenseSettingsScreen extends StatefulWidget {
  const ExpenseSettingsScreen({super.key});

  @override
  State<ExpenseSettingsScreen> createState() =>
      _ExpenseSettingsScreenState();
}

class _ExpenseSettingsScreenState extends State<ExpenseSettingsScreen> {
  final ExpenseRepository repository = ExpenseRepository();

  bool loading = true;
  bool busy = false;
  String? errorText;
  String section = 'categories';
  List<ExpenseCategoryData> categories = const [];
  List<ExpenseCounterpartyData> counterparties = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  String readableError(Object error) {
    final raw = error.toString();
    if (raw.toLowerCase().contains('duplicate key') ||
        raw.contains('company_name_uidx')) {
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
      final result = await Future.wait<dynamic>([
        repository.fetchCategories(),
        repository.fetchCounterparties(),
      ]);
      if (!mounted) return;
      setState(() {
        categories = result[0] as List<ExpenseCategoryData>;
        counterparties = result[1] as List<ExpenseCounterpartyData>;
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
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(initial == null ? 'Новая статья' : 'Изменить статью'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: AppInputFormatters.sentences,
          decoration: const InputDecoration(
            labelText: 'Название статьи',
            hintText: 'Например, Проживание',
          ),
          onSubmitted: (text) {
            if (text.trim().isNotEmpty) {
              Navigator.pop(dialogContext, text.trim());
            }
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
    if (value == null) return;
    await runBusy(() async {
      if (initial == null) {
        await repository.createCategory(value);
      } else {
        await repository.updateCategory(initial.id, value);
      }
      await load();
    });
  }

  Future<void> deleteCategory(ExpenseCategoryData item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить статью?'),
        content: Text(
          '«${item.name}» исчезнет из списка. Старые расходы сохранятся и будут показаны как «Без статьи».',
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
    final draft = await showDialog<_CounterpartyDraft>(
      context: context,
      builder: (_) => _CounterpartyDialog(initial: initial),
    );
    if (draft == null) return;
    await runBusy(() async {
      if (initial == null) {
        await repository.createCounterparty(
          name: draft.name,
          entityType: draft.entityType,
          inn: draft.inn,
          kpp: draft.kpp,
          contractNumber: draft.contractNumber,
        );
      } else {
        await repository.updateCounterparty(
          id: initial.id,
          name: draft.name,
          entityType: draft.entityType,
          inn: draft.inn,
          kpp: draft.kpp,
          contractNumber: draft.contractNumber,
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
          '«${item.name}» исчезнет из справочника. Название в уже созданных расходах останется.',
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

  Widget sectionHeader({
    required String title,
    required String description,
    required VoidCallback onAdd,
  }) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(description),
            ],
          );
          final button = FilledButton.icon(
            onPressed: busy ? null : onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить'),
          );
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [text, const SizedBox(height: 14), button],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget categoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(
          title: 'Статьи расходов',
          description: 'Соберите свой список статей для внесения расходов.',
          onAdd: editCategory,
        ),
        const SizedBox(height: 14),
        if (categories.isEmpty)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(20),
            child: Text(
              'Статей расходов пока нет.',
              textAlign: TextAlign.center,
            ),
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
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Переименовать'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
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

  Widget counterpartiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionHeader(
          title: 'Контрагенты',
          description:
              'Единый справочник компаний и физлиц для расходов и бухгалтерии.',
          onAdd: editCounterparty,
        ),
        const SizedBox(height: 14),
        if (counterparties.isEmpty)
          const PremiumWorkCard(
            radius: 22,
            padding: EdgeInsets.all(20),
            child: Text(
              'Контрагентов пока нет.',
              textAlign: TextAlign.center,
            ),
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
                    Icon(
                      item.isIndividual
                          ? Icons.person_outline_rounded
                          : Icons.apartment_rounded,
                    ),
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
                            <String>[
                              item.entityTypeLabel,
                              if (item.inn.isNotEmpty) 'ИНН ${item.inn}',
                              if (item.kpp.isNotEmpty) 'КПП ${item.kpp}',
                              if (item.contractNumber.isNotEmpty)
                                'Договор ${item.contractNumber}',
                            ].join(' · '),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
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
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Изменить'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
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
      subtitle: 'Статьи расходов и контрагенты',
      showBackButton: true,
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busy ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'categories',
                icon: Icon(Icons.sell_outlined),
                label: Text('Статьи'),
              ),
              ButtonSegment(
                value: 'counterparties',
                icon: Icon(Icons.groups_2_outlined),
                label: Text('Контрагенты'),
              ),
            ],
            selected: <String>{section},
            onSelectionChanged: busy
                ? null
                : (value) => setState(() => section = value.first),
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
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (section == 'categories')
            categoriesSection()
          else
            counterpartiesSection(),
        ],
      ),
    );
  }
}

class _CounterpartyDraft {
  final String name;
  final String entityType;
  final String inn;
  final String kpp;
  final String contractNumber;

  const _CounterpartyDraft({
    required this.name,
    required this.entityType,
    required this.inn,
    required this.kpp,
    required this.contractNumber,
  });
}

class _CounterpartyDialog extends StatefulWidget {
  final ExpenseCounterpartyData? initial;

  const _CounterpartyDialog({this.initial});

  @override
  State<_CounterpartyDialog> createState() => _CounterpartyDialogState();
}

class _CounterpartyDialogState extends State<_CounterpartyDialog> {
  late final TextEditingController nameController;
  late final TextEditingController innController;
  late final TextEditingController kppController;
  late final TextEditingController contractController;
  late String entityType;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    nameController = TextEditingController(text: initial?.name ?? '');
    innController = TextEditingController(text: initial?.inn ?? '');
    kppController = TextEditingController(text: initial?.kpp ?? '');
    contractController = TextEditingController(
      text: initial?.contractNumber ?? '',
    );
    entityType = initial?.entityType ?? 'legal_entity';
  }

  @override
  void dispose() {
    nameController.dispose();
    innController.dispose();
    kppController.dispose();
    contractController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null ? 'Новый контрагент' : 'Изменить контрагента',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: entityType,
                decoration: const InputDecoration(labelText: 'Тип'),
                items: const [
                  DropdownMenuItem(
                    value: 'legal_entity',
                    child: Text('Юридическое лицо / ООО'),
                  ),
                  DropdownMenuItem(
                    value: 'individual',
                    child: Text('Физическое лицо'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => entityType = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: AppInputFormatters.sentences,
                decoration: InputDecoration(
                  labelText: entityType == 'individual' ? 'ФИО' : 'Название',
                  hintText: entityType == 'individual'
                      ? 'Иванов Иван Иванович'
                      : 'ООО «Поставщик»',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: innController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ИНН'),
              ),
              if (entityType == 'legal_entity') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: kppController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'КПП'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: contractController,
                decoration: const InputDecoration(
                  labelText: 'Номер договора',
                  hintText: 'Необязательно',
                ),
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
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Укажи контрагента')),
              );
              return;
            }
            Navigator.pop(
              context,
              _CounterpartyDraft(
                name: name,
                entityType: entityType,
                inn: innController.text.trim(),
                kpp: entityType == 'individual'
                    ? ''
                    : kppController.text.trim(),
                contractNumber: contractController.text.trim(),
              ),
            );
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
