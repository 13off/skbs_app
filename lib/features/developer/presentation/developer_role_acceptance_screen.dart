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
  late final String selectedRole;
  RoleAcceptanceRun? run;
  bool loading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final actualRole = RoleAcceptanceRepository.normalizeRole(
      widget.profile.actualRole,
    );
    selectedRole = RoleAcceptanceRepository.scenarios.any(
      (item) => item.role == actualRole,
    )
        ? actualRole
        : 'developer';
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
                    : Icons.warning_amber_rounded,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.live
                      ? 'Проверка текущей роли: ${result.scenario.title}'
                      : 'Роль входа не совпала с профилем',
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
              _AcceptanceBadge(label: 'Заблокировано', value: result.blocked),
            ],
          ),
          if (!result.live) ...[
            const SizedBox(height: 13),
            const Text(
              'Результат не считается подтверждением: роль из профиля не совпала '
              'с серверной ролью текущей сессии. Выполните повторный вход и проверку.',
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
      title: 'Проверка текущей роли',
      showBackButton: true,
      subtitle: 'Фактические JWT, permissions, Data API и RLS текущего входа',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Проверить снова',
        onPressed: loading ? null : runChecks,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PremiumWorkCard(
            radius: 24,
            padding: EdgeInsets.all(16),
            child: Text(
              'Проверяется только реально авторизованная роль этой сессии. '
              'Переключение на чужую роль и визуальная имитация здесь не используются.',
              style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
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
                  'Не удалось выполнить проверку: $errorText',
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
