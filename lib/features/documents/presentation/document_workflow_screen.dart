import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/template_documents_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import 'document_onboarding_screen.dart';
import 'document_package_management_screen.dart';

class DocumentWorkflowScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentWorkflowScreen({
    super.key,
    required this.profile,
  });

  @override
  State<DocumentWorkflowScreen> createState() => _DocumentWorkflowScreenState();
}

class _DocumentWorkflowScreenState extends State<DocumentWorkflowScreen> {
  late Future<DocumentWorkflowDashboardData> future;

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<DocumentWorkflowDashboardData> load() async {
    if (companyId.trim().isEmpty) {
      throw StateError('Активная компания не выбрана');
    }
    return DocumentWorkflowRepository.fetchDashboard(companyId);
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  void open(Widget screen) {
    Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => screen))
        .then((_) => refresh());
  }

  Future<void> toggle(DocumentToolInstallation installation) async {
    try {
      await DocumentWorkflowRepository.setInstallation(
        companyId: companyId,
        enabled: !installation.isEnabled,
        settings: installation.settings,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            installation.isEnabled
                ? 'Документооборот отключён. Данные сохранены.'
                : 'Документооборот подключён',
          ),
        ),
      );
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> seedPackages() async {
    try {
      await Supabase.instance.client.rpc(
        'seed_default_document_packages',
        params: <String, dynamic>{'p_company_id': companyId},
      );
      await refresh();
    } catch (error) {
      showError(error);
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cleanError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Документооборот',
      subtitle: 'Полный цикл оформления сотрудника',
      child: RefreshIndicator(
        onRefresh: refresh,
        child: FutureBuilder<DocumentWorkflowDashboardData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 180),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            if (snapshot.hasError) {
              return _ErrorState(
                message: _cleanError(snapshot.error),
                onRetry: refresh,
              );
            }
            final data = snapshot.requireData;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _InstallationCard(
                  installation: data.installation,
                  canManage: widget.profile.isAdmin || widget.profile.isDeveloper,
                  onToggle: () => toggle(data.installation),
                ),
                const SizedBox(height: 14),
                if (!data.installation.isEnabled)
                  _DisabledState(
                    canManage: widget.profile.isAdmin || widget.profile.isDeveloper,
                    onEnable: () => toggle(data.installation),
                  )
                else ...[
                  _DashboardCounters(counters: data.counters),
                  const SizedBox(height: 18),
                  _QuickActions(
                    onNew: () => open(
                      DocumentOnboardingScreen(
                        profile: widget.profile,
                      ),
                    ),
                    onTemplates: () => open(
                      TemplateDocumentsScreen(profile: widget.profile),
                    ),
                    onPackages: () => open(
                      DocumentPackageManagementScreen(
                        profile: widget.profile,
                      ),
                    ),
                    onSeed: seedPackages,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Оформления',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  if (data.onboardings.isEmpty)
                    _EmptyOnboardings(
                      onCreate: () => open(
                        DocumentOnboardingScreen(profile: widget.profile),
                      ),
                    )
                  else
                    for (final onboarding in data.onboardings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _OnboardingTile(
                          onboarding: onboarding,
                          onTap: () => open(
                            DocumentOnboardingScreen(
                              profile: widget.profile,
                              onboarding: onboarding,
                            ),
                          ),
                        ),
                      ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InstallationCard extends StatelessWidget {
  final DocumentToolInstallation installation;
  final bool canManage;
  final VoidCallback onToggle;

  const _InstallationCard({
    required this.installation,
    required this.canManage,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 26,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: installation.isEnabled
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.folder_copy_outlined,
              color: installation.isEnabled
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  installation.isEnabled
                      ? 'Инструмент подключён'
                      : 'Инструмент отключён',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  installation.isEnabled
                      ? 'Шаблоны, оформление, подписанные документы и архив работают в одном месте.'
                      : 'Остальные разделы AppСтрой продолжают работать без изменений.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            Switch.adaptive(
              value: installation.isEnabled,
              onChanged: (_) => onToggle(),
            ),
        ],
      ),
    );
  }
}

class _DisabledState extends StatelessWidget {
  final bool canManage;
  final VoidCallback onEnable;

  const _DisabledState({
    required this.canManage,
    required this.onEnable,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        children: [
          const Icon(Icons.extension_off_outlined, size: 54),
          const SizedBox(height: 14),
          const Text(
            'Документооборот скрыт',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Подключите инструмент, чтобы открыть оформление, шаблоны, пакеты и архив.'
                : 'Подключить инструмент может владелец или администратор компании.',
            textAlign: TextAlign.center,
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onEnable,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Подключить инструмент'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardCounters extends StatelessWidget {
  final Map<String, int> counters;

  const _DashboardCounters({required this.counters});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _CounterCard(
            title: 'В работе',
            value: counters['active'] ?? 0,
            icon: Icons.pending_actions_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CounterCard(
            title: 'Просрочено',
            value: counters['overdue'] ?? 0,
            icon: Icons.warning_amber_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _CounterCard(
            title: 'Завершено',
            value: counters['completed'] ?? 0,
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;

  const _CounterCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onTemplates;
  final VoidCallback onPackages;
  final VoidCallback onSeed;

  const _QuickActions({
    required this.onNew,
    required this.onTemplates,
    required this.onPackages,
    required this.onSeed,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Новое оформление'),
        ),
        OutlinedButton.icon(
          onPressed: onTemplates,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Шаблоны'),
        ),
        OutlinedButton.icon(
          onPressed: onPackages,
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Пакеты'),
        ),
        TextButton.icon(
          onPressed: onSeed,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Базовые пакеты'),
        ),
      ],
    );
  }
}

class _OnboardingTile extends StatelessWidget {
  final EmployeeOnboardingRecord onboarding;
  final VoidCallback onTap;

  const _OnboardingTile({
    required this.onboarding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = onboarding.dueAt != null &&
        onboarding.dueAt!.isBefore(DateTime.now()) &&
        !onboarding.isCompleted;
    return PremiumWorkCard(
      radius: 22,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(
                  onboarding.isCompleted
                      ? Icons.task_alt_rounded
                      : overdue
                          ? Icons.warning_amber_rounded
                          : Icons.assignment_ind_outlined,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      onboarding.employeeId == null
                          ? 'Новый кандидат'
                          : 'Сотрудник ${_shortId(onboarding.employeeId!)}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_stepTitle(onboarding.currentStep)} · ${_statusTitle(onboarding.status)}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOnboardings extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyOnboardings({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 24,
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Оформлений пока нет',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onCreate,
            child: const Text('Начать оформление'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.error_outline_rounded, size: 54),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ),
      ],
    );
  }
}

String _stepTitle(String value) => switch (value) {
      DocumentOnboardingSteps.sourceFiles => 'Исходные документы',
      DocumentOnboardingSteps.sourceCompleteness => 'Комплектность',
      DocumentOnboardingSteps.recognition => 'Распознавание',
      DocumentOnboardingSteps.hrVerification => 'Проверка HR',
      DocumentOnboardingSteps.employeeCard => 'Карточка сотрудника',
      DocumentOnboardingSteps.packageAndConditions => 'Пакет и условия',
      DocumentOnboardingSteps.generation => 'Формирование',
      DocumentOnboardingSteps.printing => 'Печать',
      DocumentOnboardingSteps.signing => 'Подписание',
      DocumentOnboardingSteps.signedDocuments => 'Подписанные документы',
      DocumentOnboardingSteps.finalScans => 'Финальные сканы',
      DocumentOnboardingSteps.archiveVerification => 'Проверка архива',
      DocumentOnboardingSteps.completion => 'Завершение',
      _ => value,
    };

String _statusTitle(String value) => switch (value) {
      'draft' => 'Черновик',
      'in_progress' => 'В работе',
      'blocked' => 'Заблокировано',
      'completed' => 'Завершено',
      _ => value,
    };

String _shortId(String value) => value.length <= 8 ? value : value.substring(0, 8);

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
