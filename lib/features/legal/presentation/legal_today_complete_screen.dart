import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_operations_repository.dart';
import '../data/legal_repository.dart';
import '../data/legal_workspace_repository.dart';
import 'legal_document_complete_screen.dart';
import 'legal_employee_complete_screen.dart';
import 'legal_matter_complete_screen.dart';
import 'legal_quality_screen.dart';
import '../../../navigation/app_page_route.dart';

class LegalTodayCompleteScreen extends StatefulWidget {
  final AppUserProfile profile;

  const LegalTodayCompleteScreen({super.key, required this.profile});

  @override
  State<LegalTodayCompleteScreen> createState() =>
      _LegalTodayCompleteScreenState();
}

class _LegalTodayCompleteScreenState extends State<LegalTodayCompleteScreen> {
  late Future<List<LegalTodayItem>> future;
  String filter = 'all';

  @override
  void initState() {
    super.initState();
    future = LegalOperationsRepository.fetchTodayItems();
  }

  Future<void> refresh() async {
    final next = LegalOperationsRepository.fetchTodayItems();
    setState(() => future = next);
    await next;
  }

  String dateTimeText(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} • ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  List<LegalTodayItem> visible(List<LegalTodayItem> source) {
    if (filter == 'all') return source;
    if (filter == 'danger') {
      return source.where((item) => item.severity == 'danger').toList();
    }
    if (filter == 'documents') {
      return source
          .where(
            (item) =>
                item.itemType == 'document_attention' ||
                item.itemType == 'missing_documents',
          )
          .toList();
    }
    if (filter == 'courts') {
      return source
          .where(
            (item) =>
                item.itemType == 'process_event' ||
                item.subtitle.toLowerCase().contains('суд') ||
                item.subtitle.toLowerCase().contains('засед'),
          )
          .toList();
    }
    return source;
  }

  Future<void> openItem(LegalTodayItem item) async {
    if (item.entityType == 'legal_document') {
      final document = await LegalRepository.fetchDocument(item.entityId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalDocumentCompleteScreen(document: document),
        ),
      );
    } else if (item.entityType == 'legal_matter') {
      final matter = await LegalRepository.fetchMatter(item.entityId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        AppPageRoute<void>(
          builder: (_) => LegalMatterCompleteScreen(matter: matter),
        ),
      );
    } else if (item.employeeId.isNotEmpty || item.entityType == 'employee') {
      final employeeId = item.employeeId.isNotEmpty
          ? item.employeeId
          : item.entityId;
      final employees = await LegalWorkspaceRepository.fetchEmployees();
      final matches = employees
          .where((value) => value.id == employeeId)
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

  IconData icon(LegalTodayItem item) => switch (item.itemType) {
    'missing_documents' => Icons.assignment_late_outlined,
    'document_attention' => Icons.description_outlined,
    'matter_attention' => Icons.gavel_outlined,
    'process_event' => Icons.event_available_outlined,
    'recovery' => Icons.payments_outlined,
    _ => Icons.notifications_active_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Сегодня',
      subtitle:
          'Только то, что требует действия: сроки, риски, документы и решения',
      headerTrailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push<void>(
                context,
                AppPageRoute<void>(builder: (_) => const LegalQualityScreen()),
              );
              if (mounted) await refresh();
            },
            icon: const Icon(Icons.health_and_safety_outlined),
            label: const Text('Контроль базы'),
          ),
          IconButton.filledTonal(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      child: FutureBuilder<List<LegalTodayItem>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return PremiumWorkCard(
                child: Text('Не удалось загрузить очередь: ${snapshot.error}'),
              );
            }
            return const PremiumWorkCard(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final source = snapshot.data!;
          final items = visible(source);
          final danger = source
              .where((item) => item.severity == 'danger')
              .length;
          final missing = source
              .where((item) => item.itemType == 'missing_documents')
              .length;
          final process = source
              .where((item) => item.itemType == 'process_event')
              .length;
          final recoveries = source
              .where((item) => item.itemType == 'recovery')
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _TodayMetric(
                      label: 'Всего',
                      value: source.length,
                      icon: Icons.inbox_outlined,
                    ),
                    _TodayMetric(
                      label: 'Срочно',
                      value: danger,
                      icon: Icons.error_outline_rounded,
                    ),
                    _TodayMetric(
                      label: 'Неполные досье',
                      value: missing,
                      icon: Icons.folder_off_outlined,
                    ),
                    _TodayMetric(
                      label: 'События суда',
                      value: process,
                      icon: Icons.account_balance_outlined,
                    ),
                    _TodayMetric(
                      label: 'Взыскания',
                      value: recoveries,
                      icon: Icons.payments_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    <(String, String)>[
                          ('all', 'Все'),
                          ('danger', 'Срочно'),
                          ('documents', 'Документы'),
                          ('courts', 'Суды и сроки'),
                        ]
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.$2),
                            selected: filter == item.$1,
                            onSelected: (_) => setState(() => filter = item.$1),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                const PremiumWorkCard(
                  radius: 24,
                  padding: EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.task_alt_rounded, size: 48),
                      SizedBox(height: 10),
                      Text(
                        'На сейчас ничего не горит',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Новые сроки, риски и недостающие документы появятся здесь автоматически.',
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
                        leading: CircleAvatar(child: Icon(icon(item))),
                        title: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          <String>[
                            if (item.subtitle.isNotEmpty) item.subtitle,
                            if (item.dueAt != null) dateTimeText(item.dueAt),
                            if (item.severity == 'danger') 'срочно',
                          ].join(' • '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => openItem(item),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _TodayMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
