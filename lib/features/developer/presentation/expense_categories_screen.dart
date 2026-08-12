import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../expenses/data/expense_repository.dart';

class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key});

  @override
  State<ExpenseCategoriesScreen> createState() =>
      _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  final ExpenseRepository repository = ExpenseRepository();

  bool loading = true;
  bool busy = false;
  String? errorText;
  List<ExpenseCategoryData> categories = const [];

  @override
  void initState() {
    super.initState();
    load();
  }

  String readableError(Object error) {
    final raw = error.toString();
    if (raw.contains('expense_categories_company_name_uidx') ||
        raw.toLowerCase().contains('duplicate key')) {
      return 'Такая статья расходов уже есть.';
    }
    final match = RegExp(r'message:\s*([^,}]+)').firstMatch(raw);
    return match?.group(1)?.trim() ??
        raw.replaceFirst('PostgrestException(', '').replaceAll(')', '');
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final data = await repository.fetchCategories();
      if (!mounted) return;
      setState(() {
        categories = data;
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
          initial == null ? 'Добавить статью расходов' : 'Переименовать статью',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Название статьи',
            hintText: 'Например, Инструмент',
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
      builder: (context) => AlertDialog(
        title: const Text('Удалить статью расходов?'),
        content: Text(
          '«${item.name}» исчезнет из списка. Уже созданные расходы не удалятся и будут показаны как «Без статьи».',
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
      await repository.deleteCategory(item.id);
      await load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Статьи расходов',
      subtitle: 'Справочник для раздела «Расходы» руководителя',
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
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Справочник статей',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Добавляй, переименовывай и удаляй статьи здесь. Руководитель только выбирает их при внесении расхода.',
                            ),
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
            ),
    );
  }
}
