import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import 'employee_passport_directory_screen.dart';
import 'employee_professional_passport_screen.dart';
import 'employee_team_screen.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeCommunityHubScreen extends StatelessWidget {
  final AppUserProfile profile;

  const EmployeeCommunityHubScreen({super.key, required this.profile});

  Future<void> _openTeam(BuildContext context) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => profile.isRolePreview
            ? const EmployeeTeamSeedDirectoryScreen()
            : const EmployeeTeamScreen(),
      ),
    );
  }

  Future<void> _openPassport(BuildContext context) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => profile.isRolePreview
            ? const EmployeePassportDirectoryScreen()
            : EmployeeProfessionalPassportScreen(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppPage(
        title: 'Команда',
        subtitle: profile.isRolePreview
            ? 'Реальные сотрудники, объекты и профессиональные паспорта'
            : 'Коллеги вашего объекта и профессиональный профиль',
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HubIcon(icon: Icons.groups_rounded),
                  const SizedBox(height: 16),
                  Text(
                    'Команда объекта',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.isRolePreview
                        ? 'Выберите конкретного сотрудника и посмотрите реальный состав его текущего объекта.'
                        : 'Посмотрите, кто работает рядом, чем занимаются коллеги и какой опыт подтверждён в AppСтрой.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  PremiumActionButton(
                    label: profile.isRolePreview
                        ? 'Выбрать сотрудника'
                        : 'Открыть команду',
                    icon: Icons.groups_rounded,
                    onPressed: () => _openTeam(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HubIcon(icon: Icons.badge_rounded),
                  const SizedBox(height: 16),
                  Text(
                    profile.isRolePreview
                        ? 'Паспорта специалистов'
                        : 'Мой паспорт специалиста',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.isRolePreview
                        ? 'Откройте подтверждённый профиль конкретного человека без вымышленных показателей.'
                        : 'Дополните квалификацию, навыки и опыт. Рабочая статистика считается автоматически.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _openPassport(context),
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(
                      profile.isRolePreview
                          ? 'Выбрать специалиста'
                          : 'Открыть паспорт',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'В команде не показываются телефоны, ставки, выплаты, комментарии и кадровые документы. Расширенную профессиональную часть сотрудник открывает сам.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubIcon extends StatelessWidget {
  final IconData icon;

  const _HubIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        size: 30,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}
