import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import 'legal_document_complete_screen.dart';
import 'legal_employee_complete_screen.dart';
import 'legal_matter_complete_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalQualityScreen extends StatefulWidget {
  const LegalQualityScreen({super.key});

  @override
  State<LegalQualityScreen> createState() => _LegalQualityScreenState();
}

class _LegalQualityScreenState extends State<LegalQualityScreen> {
  late Future<List<LegalQualityIssue>> future;

  @override
  void initState() {
    super.initState();
    future = LegalOperationsRepository.fetchQualityReport();
  }

  Future<void> refresh() async {
    final next = LegalOperationsRepository.fetchQualityReport();
    setState(() => future = next);
    await next;
  }

  Future<void> openIssue(LegalQualityIssue issue) async {
    if (issue.entityType == 'legal_document') {
      final document = await LegalRepository.fetchDocument(issue.entityId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalDocumentCompleteScreen(document: document),
        ),
      );
    } else if (issue.entityType == 'legal_matter') {
      final matter = await LegalRepository.fetchMatter(issue.entityId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalMatterCompleteScreen(matter: matter),
        ),
      );
    } else if (issue.entityType == 'employee') {
      final employees = await LegalWorkspaceRepository.fetchEmployees();
      final matches = employees
          .where((item) => item.id == issue.entityId)
          .toList();
      if (!mounted || matches.isEmpty) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalEmployeeCompleteScreen(employee: matches.first),
        ),
      );
    }
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Контроль базы')),
      body: AppPage(
        title: 'Контроль качества',
        subtitle:
            'Битые файлы, документы без связей, пустые карточки и незакрытые проблемы',
        headerTrailing: IconButton.filledTonal(
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        child: FutureBuilder<List<LegalQualityIssue>>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) {
                return PremiumWorkCard(
                  child: Text('Не удалось проверить базу: ${snapshot.error}'),
                );
              }
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final items = snapshot.data!;
            final danger = items
                .where((item) => item.severity == 'danger')
                .length;
            final warnings = items
                .where((item) => item.severity == 'warning')
                .length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      Text(
                        'Проблем: ${items.length}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Критичных: $danger',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Предупреждений: $warnings',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const PremiumWorkCard(
                    radius: 22,
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.verified_rounded, size: 44),
                        SizedBox(height: 10),
                        Text(
                          'Технических проблем в юридической базе не найдено',
                        ),
                      ],
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PremiumWorkCard(
                        radius: 20,
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(
                              item.severity == 'danger'
                                  ? Icons.error_outline_rounded
                                  : item.severity == 'warning'
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline_rounded,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(item.details),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => openIssue(item),
                        ),
                      ),
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
