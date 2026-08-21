import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_process_repository.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_matter_complete_screen.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalMattersCompleteScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalMattersCompleteScreen({super.key, required this.profile});

  @override
  State<LegalMattersCompleteScreen> createState() =>
      _LegalMattersCompleteScreenState();
}

class _LegalMattersCompleteScreenState
    extends State<LegalMattersCompleteScreen> {
  late Future<List<LegalMatter>> future;
  final searchController = TextEditingController();
  String filter = 'active';

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<LegalMatter>> load() =>
      LegalRepository.fetchMatters(search: searchController.text);

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  List<LegalMatter> visible(List<LegalMatter> source) {
    return switch (filter) {
      'all' => source,
      'court' => source.where(legalMatterIsCourt).toList(),
      'claim' =>
        source
            .where((item) => item.matterType == LegalMatterType.claim)
            .toList(),
      'overdue' => source.where((item) => item.isOverdue).toList(),
      'manager' => source.where((item) => item.needsManager).toList(),
      _ =>
        source
            .where(
              (item) =>
                  item.status != LegalMatterStatus.resolved &&
                  item.status != LegalMatterStatus.closed,
            )
            .toList(),
    };
  }

  Future<void> add() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(builder: (_) => const LegalMatterEditorScreen()),
    );
    if (saved == true && mounted) await refresh();
  }

  IconData icon(LegalMatter item) {
    if (legalMatterIsCourt(item)) return Icons.account_balance_outlined;
    if (item.matterType == LegalMatterType.claim)
      return Icons.mark_email_read_outlined;
    if (item.matterType == LegalMatterType.violation)
      return Icons.report_problem_outlined;
    return Icons.gavel_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Дела',
      subtitle: 'Вся юридическая работа: задачи, споры, претензии и суды',
      headerTrailing: FilledButton.icon(
        onPressed: add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новое дело'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText:
                        'Поиск по делу, сотруднику, объекту или контрагенту',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: refresh,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                  onSubmitted: (_) => refresh(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      <(String, String)>[
                            ('active', 'В работе'),
                            ('court', 'Суды'),
                            ('claim', 'Претензии'),
                            ('overdue', 'Просрочено'),
                            ('manager', 'Решение руководителя'),
                            ('all', 'Все'),
                          ]
                          .map(
                            (item) => ChoiceChip(
                              label: Text(item.$2),
                              selected: filter == item.$1,
                              onSelected: (_) =>
                                  setState(() => filter = item.$1),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<LegalMatter>>(
            future: future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                if (snapshot.hasError) {
                  return PremiumWorkCard(
                    child: Text('Не удалось загрузить дела: ${snapshot.error}'),
                  );
                }
                return const PremiumWorkCard(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              final source = snapshot.data!;
              final items = visible(source);
              if (items.isEmpty) {
                return PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Text('По выбранному разделу дел нет'),
                      if (source.isEmpty) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: add,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Создать первое дело'),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return Column(
                children: items.map((item) {
                  final links = <String>[
                    if (item.employeeName.isNotEmpty) item.employeeName,
                    if (item.objectName.isNotEmpty) item.objectName,
                    if (item.counterpartyName.isNotEmpty) item.counterpartyName,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PremiumWorkCard(
                      radius: 20,
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(icon(item))),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          <String>[
                            legalMatterDisplayType(item),
                            item.statusTitle,
                            '${item.riskTitle} риск',
                            if (item.isOverdue) 'срок просрочен',
                            if (item.needsManager) 'ждёт решения руководителя',
                            ...links,
                          ].join(' • '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            AppPageRoute<void>(
                              builder: (_) =>
                                  LegalMatterCompleteScreen(matter: item),
                            ),
                          );
                          if (mounted) await refresh();
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
