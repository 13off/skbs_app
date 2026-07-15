import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';

part 'legal_matter_details_part.dart';
part 'legal_matter_editor_part.dart';

class LegalMattersScreen extends StatefulWidget {
  final bool highRiskOnly;
  final bool managerOnly;
  final AppUserProfile? profile;

  const LegalMattersScreen({
    super.key,
    this.highRiskOnly = false,
    this.managerOnly = false,
    this.profile,
  });

  @override
  State<LegalMattersScreen> createState() => _LegalMattersScreenState();
}

class _LegalMattersScreenState extends State<LegalMattersScreen> {
  final searchController = TextEditingController();
  late Future<List<LegalMatter>> future;
  StreamSubscription<AppDataChange>? subscription;
  bool attentionOnly = false;

  bool get managerMode => widget.profile?.isAdmin == true;

  @override
  void initState() {
    super.initState();
    attentionOnly = widget.highRiskOnly || widget.managerOnly;
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.legal)) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<List<LegalMatter>> load() async {
    var matters = await LegalRepository.fetchMatters(
      search: searchController.text,
      attentionOnly: attentionOnly,
    );
    if (widget.highRiskOnly) {
      matters = matters.where((item) => item.isHighRisk).toList();
    }
    if (widget.managerOnly) {
      matters = matters.where((item) => item.needsManager).toList();
    }
    return matters;
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> openEditor([LegalMatter? matter]) async {
    final saved = await Navigator.push<bool>(
      context,
      CupertinoPageRoute<bool>(builder: (_) => LegalMatterEditorScreen(matter: matter)),
    );
    if (saved == true && mounted) refresh();
  }

  Future<void> openDetails(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => LegalMatterDetailsScreen(
          matter: matter,
          canDecide: managerMode,
        ),
      ),
    );
    if (mounted) refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: managerMode ? 'Решения и риски' : 'Вопросы и риски',
      subtitle: managerMode
          ? 'Юридические вопросы, по которым требуется решение руководителя'
          : 'Претензии, нарушения, споры, задачи и риски компании',
      headerTrailing: managerMode
          ? null
          : FilledButton.icon(
              onPressed: () => openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить'),
            ),
      child: Column(
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск по вопросам',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(onPressed: refresh, icon: const Icon(Icons.arrow_forward_rounded)),
                  ),
                  onSubmitted: (_) => refresh(),
                ),
                if (!widget.highRiskOnly && !widget.managerOnly)
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Только требующие внимания'),
                    value: attentionOnly,
                    onChanged: (value) {
                      setState(() {
                        attentionOnly = value;
                        future = load();
                      });
                    },
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
                  return PremiumWorkCard(child: Padding(padding: const EdgeInsets.all(22), child: Text('Ошибка: ${snapshot.error}')));
                }
                return const PremiumWorkCard(child: Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())));
              }
              final matters = snapshot.data!;
              if (matters.isEmpty) {
                return const PremiumWorkCard(child: Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Вопросы не найдены'))));
              }
              return Column(
                children: matters.map((matter) {
                  final meta = <String>[
                    matter.typeTitle,
                    '${matter.riskTitle} риск',
                    matter.statusTitle,
                    if (matter.objectName.isNotEmpty) matter.objectName,
                  ];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumPressable(
                      onTap: () => openDetails(matter),
                      borderRadius: BorderRadius.circular(22),
                      child: PremiumWorkCard(
                        radius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: matter.isHighRisk ? const Color(0xFFF4E9E7) : const Color(0xFFF0F1F3),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(matter.isHighRisk ? Icons.warning_amber_rounded : Icons.gavel_outlined),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(matter.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 5),
                                  Text(meta.join(' • '), style: const TextStyle(color: Color(0xFF5F646A), fontWeight: FontWeight.w700)),
                                  if (matter.needsManager) ...[
                                    const SizedBox(height: 7),
                                    const Text('Требуется решение руководителя', style: TextStyle(color: Color(0xFF874540), fontSize: 12, fontWeight: FontWeight.w900)),
                                  ],
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A8F94)),
                          ],
                        ),
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
