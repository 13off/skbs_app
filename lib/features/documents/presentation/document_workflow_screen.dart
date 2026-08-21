import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/template_documents_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import 'document_onboarding_screen.dart';
import 'document_package_management_screen.dart';
import '../../../navigation/app_page_route.dart';

class DocumentWorkflowScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentWorkflowScreen({super.key, required this.profile});

  @override
  State<DocumentWorkflowScreen> createState() => _DocumentWorkflowScreenState();
}

class _DocumentWorkflowScreenState extends State<DocumentWorkflowScreen> {
  late Future<DocumentWorkflowDashboardData> future;
  bool creating = false;

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<DocumentWorkflowDashboardData> load() {
    return DocumentWorkflowRepository.fetchDashboard(companyId);
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  void open(Widget screen) {
    Navigator.of(
      context,
    ).push<void>(AppPageRoute<void>(builder: (_) => screen));
  }

  Future<void> seedPackages() async {
    try {
      await DocumentWorkflowRepository.seedDefaultPackages(companyId);
      await refresh();
      _message('Базовые пакеты обновлены');
    } catch (error) {
      _message(_cleanError(error));
    }
  }

  Future<void> createOnboarding(DocumentWorkflowDashboardData dashboard) async {
    if (creating || !dashboard.access.canCreate) return;
    setState(() => creating = true);
    try {
      final values = await Future.wait<dynamic>(<Future<dynamic>>[
        DocumentWorkflowRepository.fetchCandidates(companyId),
        DocumentWorkflowRepository.fetchEmployees(companyId),
        DocumentWorkflowRepository.fetchObjects(companyId),
        DocumentWorkflowRepository.fetchPackages(companyId),
      ]);
      if (!mounted) return;
      final draft = await showDialog<_OnboardingDraft>(
        context: context,
        builder: (context) => _CreateOnboardingDialog(
          candidates: values[0] as List<DocumentCandidateOption>,
          employees: values[1] as List<DocumentEmployeeOption>,
          objects: values[2] as List<DocumentObjectOption>,
          packages: values[3] as List<DocumentPackageRecord>,
        ),
      );
      if (draft == null || !mounted) return;
      final onboarding = await DocumentWorkflowRepository.createOnboarding(
        companyId: companyId,
        recruitmentApplicationId: draft.candidateId,
        employeeId: draft.employeeId,
        packageId: draft.packageId,
        objectId: draft.objectId,
        onboardingType: draft.onboardingType,
        dueAt: draft.dueAt,
        conditions: <String, dynamic>{
          'position': draft.position,
          'compensation': draft.compensation,
          'start_date': draft.startDate,
          'notes': draft.notes,
          'payment_term': draft.onboardingType == 'gph'
              ? 'Вознаграждение по договору'
              : 'Оплата по условиям оформления',
        },
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        AppPageRoute<void>(
          builder: (_) => DocumentOnboardingScreen(
            profile: widget.profile,
            onboardingId: onboarding.id,
          ),
        ),
      );
      await refresh();
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Оформления',
      subtitle: 'Оформление сотрудника от исходников до архива',
      onRefresh: refresh,
      child: FutureBuilder<DocumentWorkflowDashboardData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: _cleanError(snapshot.error),
              onRetry: refresh,
            );
          }
          final data = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!data.installation.isEnabled) ...[
                const SizedBox(height: 14),
                const PremiumWorkCard(
                  radius: 24,
                  child: Text(
                    'Инструмент отключён. Данные, шаблоны и ранее созданные '
                    'архивы не удаляются. После включения появляются мастер, '
                    'пакеты и история.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ] else if (!data.access.canView) ...[
                const SizedBox(height: 14),
                const PremiumWorkCard(
                  radius: 24,
                  child: Text(
                    'Инструмент подключён, но вашей роли не выдано право '
                    'просмотра документооборота.',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                _Metrics(data: data),
                const SizedBox(height: 14),
                _Actions(
                  data: data,
                  creating: creating,
                  onCreate: () => createOnboarding(data),
                  onTemplates: () =>
                      open(TemplateDocumentsScreen(profile: widget.profile)),
                  onPackages: () => open(
                    DocumentPackageManagementScreen(profile: widget.profile),
                  ),
                  onSeedPackages: seedPackages,
                ),
                const SizedBox(height: 18),
                Text(
                  'Оформления',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (data.onboardings.isEmpty)
                  const PremiumWorkCard(
                    radius: 24,
                    child: Text(
                      'Процессов пока нет. Создайте оформление из кандидата '
                      'CRM или выберите уже существующего сотрудника.',
                    ),
                  )
                else
                  for (final onboarding in data.onboardings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OnboardingTile(
                        onboarding: onboarding,
                        onTap: () async {
                          await Navigator.of(context).push<void>(
                            AppPageRoute<void>(
                              builder: (_) => DocumentOnboardingScreen(
                                profile: widget.profile,
                                onboardingId: onboarding.id,
                              ),
                            ),
                          );
                          await refresh();
                        },
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final DocumentWorkflowDashboardData data;

  const _Metrics({required this.data});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Metric(title: 'В работе', value: data.activeCount),
        _Metric(title: 'Просрочено', value: data.overdueCount),
        _Metric(title: 'Завершено', value: data.completedCount),
        _Metric(title: 'Пакетов', value: data.packages.length),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  final String title;
  final int value;

  const _Metric({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: PremiumWorkCard(
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final DocumentWorkflowDashboardData data;
  final bool creating;
  final VoidCallback onCreate;
  final VoidCallback onTemplates;
  final VoidCallback onPackages;
  final VoidCallback onSeedPackages;

  const _Actions({
    required this.data,
    required this.creating,
    required this.onCreate,
    required this.onTemplates,
    required this.onPackages,
    required this.onSeedPackages,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          if (data.access.canCreate)
            FilledButton.icon(
              onPressed: creating ? null : onCreate,
              icon: creating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Новое оформление'),
            ),
          if (data.access.canViewTemplates)
            OutlinedButton.icon(
              onPressed: onTemplates,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Шаблоны'),
            ),
          if (data.access.canManagePackages)
            OutlinedButton.icon(
              onPressed: onPackages,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Пакеты'),
            ),
          if (data.access.canManagePackages && data.packages.isEmpty)
            TextButton.icon(
              onPressed: onSeedPackages,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Добавить базовые пакеты'),
            ),
        ],
      ),
    );
  }
}

class _OnboardingTile extends StatelessWidget {
  final EmployeeOnboardingRecord onboarding;
  final VoidCallback onTap;

  const _OnboardingTile({required this.onboarding, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final progressIndex = DocumentOnboardingSteps.ordered.indexOf(
      onboarding.currentStep,
    );
    final progress = onboarding.isCompleted
        ? 1.0
        : ((progressIndex < 0 ? 0 : progressIndex) + 1) /
              DocumentOnboardingSteps.ordered.length;
    return PremiumWorkCard(
      radius: 24,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      onboarding.isCompleted
                          ? Icons.check_rounded
                          : Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          onboarding.personName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          [
                            if (onboarding.packageTitle.isNotEmpty)
                              onboarding.packageTitle,
                            if (onboarding.objectName.isNotEmpty)
                              onboarding.objectName,
                          ].join(' · '),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress.clamp(0, 1)),
              const SizedBox(height: 7),
              Text(
                onboarding.isCompleted
                    ? 'Оформление завершено'
                    : 'Этап ${progressIndex < 0 ? 1 : progressIndex + 1} из ${DocumentOnboardingSteps.ordered.length}: ${_stepTitle(onboarding.currentStep)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOnboardingDialog extends StatefulWidget {
  final List<DocumentCandidateOption> candidates;
  final List<DocumentEmployeeOption> employees;
  final List<DocumentObjectOption> objects;
  final List<DocumentPackageRecord> packages;

  const _CreateOnboardingDialog({
    required this.candidates,
    required this.employees,
    required this.objects,
    required this.packages,
  });

  @override
  State<_CreateOnboardingDialog> createState() =>
      _CreateOnboardingDialogState();
}

class _CreateOnboardingDialogState extends State<_CreateOnboardingDialog> {
  String source = 'candidate';
  String? candidateId;
  String? employeeId;
  String? objectId;
  String? packageId;
  String onboardingType = 'gph';
  DateTime? dueAt;
  final position = TextEditingController();
  final compensation = TextEditingController();
  final startDate = TextEditingController();
  final notes = TextEditingController();

  @override
  void dispose() {
    position.dispose();
    compensation.dispose();
    startDate.dispose();
    notes.dispose();
    super.dispose();
  }

  DocumentCandidateOption? get candidate {
    for (final item in widget.candidates) {
      if (item.id == candidateId) return item;
    }
    return null;
  }

  void selectCandidate(String? value) {
    setState(() {
      candidateId = value;
      final selected = candidate;
      if (selected != null) {
        employeeId = selected.employeeId;
        objectId = selected.objectId.isEmpty ? objectId : selected.objectId;
        if (position.text.trim().isEmpty) position.text = selected.position;
      }
    });
  }

  void selectPackage(String? value) {
    setState(() {
      packageId = value;
      for (final item in widget.packages) {
        if (item.id == value) {
          onboardingType = item.onboardingType;
          break;
        }
      }
    });
  }

  Future<void> pickDueDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: dueAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (result != null) setState(() => dueAt = result);
  }

  void submit() {
    final hasPerson = source == 'candidate'
        ? candidateId != null
        : employeeId != null;
    if (!hasPerson) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите кандидата или сотрудника')),
      );
      return;
    }
    Navigator.pop(
      context,
      _OnboardingDraft(
        candidateId: source == 'candidate' ? candidateId : null,
        employeeId: employeeId,
        objectId: objectId,
        packageId: packageId,
        onboardingType: onboardingType,
        dueAt: dueAt,
        position: position.text.trim(),
        compensation: compensation.text.trim(),
        startDate: startDate.text.trim(),
        notes: notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новое оформление'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'candidate',
                    icon: Icon(Icons.person_search_outlined),
                    label: Text('Кандидат'),
                  ),
                  ButtonSegment(
                    value: 'employee',
                    icon: Icon(Icons.badge_outlined),
                    label: Text('Сотрудник'),
                  ),
                ],
                selected: <String>{source},
                onSelectionChanged: (values) {
                  setState(() {
                    source = values.first;
                    if (source == 'employee') candidateId = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (source == 'candidate')
                DropdownButtonFormField<String>(
                  initialValue: candidateId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Кандидат из CRM',
                  ),
                  items: [
                    for (final item in widget.candidates)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.objectName.isEmpty
                              ? item.fullName
                              : '${item.fullName} · ${item.objectName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: selectCandidate,
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: employeeId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Сотрудник'),
                  items: [
                    for (final item in widget.employees)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(
                          item.objectName.isEmpty
                              ? item.fullName
                              : '${item.fullName} · ${item.objectName}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    employeeId = value;
                    for (final item in widget.employees) {
                      if (item.id == value) {
                        objectId = item.objectId.isEmpty
                            ? objectId
                            : item.objectId;
                        if (position.text.trim().isEmpty) {
                          position.text = item.position;
                        }
                        break;
                      }
                    }
                  }),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: packageId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Пакет документов',
                ),
                items: [
                  for (final item in widget.packages)
                    DropdownMenuItem(value: item.id, child: Text(item.title)),
                ],
                onChanged: selectPackage,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: objectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Объект'),
                items: [
                  for (final item in widget.objects)
                    DropdownMenuItem(value: item.id, child: Text(item.name)),
                ],
                onChanged: (value) => setState(() => objectId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: position,
                decoration: const InputDecoration(labelText: 'Должность'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: compensation,
                decoration: InputDecoration(
                  labelText: onboardingType == 'gph'
                      ? 'Вознаграждение по договору'
                      : 'Оплата',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: startDate,
                decoration: const InputDecoration(
                  labelText: 'Дата начала',
                  hintText: 'ДД.ММ.ГГГГ',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  dueAt == null
                      ? 'Срок оформления не задан'
                      : 'Срок: ${_dateText(dueAt!)}',
                ),
                trailing: TextButton(
                  onPressed: pickDueDate,
                  child: const Text('Выбрать'),
                ),
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий к оформлению',
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
          onPressed: submit,
          child: const Text('Создать оформление'),
        ),
      ],
    );
  }
}

class _OnboardingDraft {
  final String? candidateId;
  final String? employeeId;
  final String? objectId;
  final String? packageId;
  final String onboardingType;
  final DateTime? dueAt;
  final String position;
  final String compensation;
  final String startDate;
  final String notes;

  const _OnboardingDraft({
    required this.candidateId,
    required this.employeeId,
    required this.objectId,
    required this.packageId,
    required this.onboardingType,
    required this.dueAt,
    required this.position,
    required this.compensation,
    required this.startDate,
    required this.notes,
  });
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}

String _stepTitle(String code) => switch (code) {
  'source_files' => 'Исходные документы',
  'source_completeness' => 'Комплектность',
  'recognition' => 'Распознавание данных',
  'hr_verification' => 'Проверка HR',
  'employee_card' => 'Карточка сотрудника',
  'package_and_conditions' => 'Пакет и условия',
  'generation' => 'Формирование документов',
  'printing' => 'Печать',
  'signing' => 'Подписание',
  'signed_documents' => 'Подписанные документы',
  'final_scans' => 'Финальные сканы',
  'archive_verification' => 'Проверка архива',
  'completion' => 'Завершение',
  _ => code,
};

String _dateText(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
