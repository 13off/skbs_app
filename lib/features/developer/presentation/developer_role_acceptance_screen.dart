import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/role_acceptance_repository.dart';

class DeveloperRoleAcceptanceScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperRoleAcceptanceScreen({super.key, required this.profile});

  @override
  State<DeveloperRoleAcceptanceScreen> createState() =>
      _DeveloperRoleAcceptanceScreenState();
}

class _DeveloperRoleAcceptanceScreenState
    extends State<DeveloperRoleAcceptanceScreen> {
  late String selectedRole;
  RoleAcceptanceRun? run;
  bool loading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    selectedRole = RoleAcceptanceRepository.normalizeRole(
      widget.profile.actualRole,
    );
    if (!RoleAcceptanceRepository.scenarios.any(
      (item) => item.role == selectedRole,
    )) {
      selectedRole = 'developer';
    }
    runChecks();
  }

  Future<void> runChecks() async {
    if (loading) return;
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final result = await RoleAcceptanceRepository.run(
        selectedRole: selectedRole,
        fallbackRole: widget.profile.actualRole,
        fallbackCompanyId: widget.profile.activeCompanyId,
        fallbackObjectName: widget.profile.objectName,
      );
      if (!mounted) return;
      setState(() => run = result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        run = null;
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void selectRole(String role) {
    if (selectedRole == role) return;
    setState(() {
      selectedRole = role;
      run = null;
      errorText = null;
    });
    runChecks();
  }

  Color statusColor(BuildContext context, RoleAcceptanceStatus status) {
    return switch (status) {
      RoleAcceptanceStatus.passed => const Color(0xFF2E7D52),
      RoleAcceptanceStatus.failed => Theme.of(context).colorScheme.error,
      RoleAcceptanceStatus.blocked => const Color(0xFF9A6816),
    };
  }

  IconData statusIcon(RoleAcceptanceStatus status) {
    return switch (status) {
      RoleAcceptanceStatus.passed => Icons.check_circle_outline_rounded,
      RoleAcceptanceStatus.failed => Icons.error_outline_rounded,
      RoleAcceptanceStatus.blocked => Icons.lock_clock_outlined,
    };
  }

  Widget scenarioCard(RoleAcceptanceScenario scenario) {
    final active = scenario.role == selectedRole;
    return ChoiceChip(
      selected: active,
      label: Text(scenario.title),
      avatar: Icon(switch (scenario.role) {
        'admin' => Icons.admin_panel_settings_outlined,
        'developer' => Icons.developer_mode_outlined,
        'foreman' => Icons.engineering_outlined,
        'hr' => Icons.person_search_outlined,
        'accountant' => Icons.calculate_outlined,
        'lawyer' => Icons.gavel_outlined,
        _ => Icons.person_outline,
      }, size: 18),
      onSelected: (_) => selectRole(scenario.role),
    );
  }

  Widget summaryCard(RoleAcceptanceRun result) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.live
                    ? Icons.verified_user_outlined
                    : Icons.preview_outlined,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.live
                      ? 'Live-приёмка: ${result.scenario.title}'
                      : 'Контракт роли: ${result.scenario.title}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Платформа: ${result.scenario.platform}\n'
            'Область: ${result.scenario.objectScope}\n'
            'Серверная роль текущего входа: ${result.serverRole}',
            style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AcceptanceBadge(label: 'Пройдено', value: result.passed),
              _AcceptanceBadge(label: 'Ошибки', value: result.failed),
              _AcceptanceBadge(label: 'Нужен вход', value: result.blocked),
            ],
          ),
          if (!result.live) ...[
            const SizedBox(height: 13),
            const Text(
              'Клиентский просмотр роли не используется как доказательство. '
              'Для полной приёмки выбери роль и войди отдельной реальной тестовой учётной записью.',
              style: TextStyle(
                color: Color(0xFF8A5A12),
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget checkCard(RoleAcceptanceCheck check) {
    final color = statusColor(context, check.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon(check.status), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    check.description,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    check.result,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Ролевая приёмка',
      showBackButton: true,
      subtitle: 'Фактические JWT, permissions, Data API и RLS каждой профессии',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Проверить снова',
        onPressed: loading ? null : runChecks,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выбери профессию',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Выбранная роль показывает контракт. Live-результат появляется только когда серверная роль текущего входа совпадает с выбранной.',
                  style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RoleAcceptanceRepository.scenarios
                      .map(scenarioCard)
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorText != null)
            PremiumWorkCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Не удалось выполнить приёмку: $errorText',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          else if (run != null) ...[
            summaryCard(run!),
            const SizedBox(height: 14),
            ...run!.checks.map(checkCard),
          ],
          const SizedBox(height: 10),
          const Text(
            'Проверка ничего не создаёт и не изменяет. Используются только RPC разрешений и минимальный SELECT через JWT текущего пользователя.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AcceptanceBadge extends StatelessWidget {
  final String label;
  final int value;

  const _AcceptanceBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
