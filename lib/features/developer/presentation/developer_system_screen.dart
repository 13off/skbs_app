import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../screens/notification_control_center_screen.dart';
import '../../../screens/push_notification_settings_screen.dart';
import '../../../screens/template_documents_screen.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../ai/presentation/operational_audit_launcher_screen.dart';
import '../../company/presentation/company_management_screen.dart';
import '../../company/presentation/company_switcher_screen.dart';
import '../../compliance/presentation/company_compliance_screen.dart';
import '../../dispatcher/presentation/dispatcher_settings_screen.dart';
import 'developer_constructor_screen.dart';
import 'developer_panel_screen.dart';
import 'developer_readiness_screen.dart';
import 'developer_role_acceptance_screen.dart';
import 'expense_categories_screen.dart';
import 'role_permission_matrix_screen.dart';
import '../../../navigation/app_page_route.dart';

class DeveloperSystemScreen extends StatelessWidget {
  final AppUserProfile profile;

  const DeveloperSystemScreen({super.key, required this.profile});

  void open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push<void>(AppPageRoute<void>(builder: (_) => screen));
  }

  Widget constructorCard(BuildContext context) {
    final companySelected = profile.activeCompanyId.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    final statusColor = companySelected
        ? const Color(0xFF2EAF72)
        : const Color(0xFFE09B32);

    return PremiumWorkCard(
      radius: 32,
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.25),
                  scheme.primary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.dashboard_customize_rounded,
              color: scheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Text(
              'Конструктор компании',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.35,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: statusColor.withValues(alpha: 0.24)),
            ),
            child: Text(
              companySelected ? 'Компания выбрана' : 'Выберите компанию',
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 12),
      child: Text(
        value,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.25,
        ),
      ),
    );
  }

  Widget actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumPressable(
      onTap: onTap,
      pressedScale: 0.975,
      hoverScale: 1.012,
      borderRadius: BorderRadius.circular(28),
      child: PremiumWorkCard(
        radius: 28,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.20),
                    scheme.primary.withValues(alpha: 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(icon, color: scheme.primary, size: 27),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: scheme.onSurfaceVariant,
              size: 17,
            ),
          ],
        ),
      ),
    );
  }

  Widget actionGrid(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - 14) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Конструктор',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          constructorCard(context),
          const SizedBox(height: 24),
          sectionTitle(context, 'Логика приложения'),
          actionGrid(context, [
            actionCard(
              context,
              icon: Icons.rule_outlined,
              title: 'Ограничения задач и объектов',
              onTap: () =>
                  open(context, DeveloperPanelScreen(profile: profile)),
            ),
            actionCard(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Роли и права',
              onTap: () => open(context, const RolePermissionMatrixScreen()),
            ),
            actionCard(
              context,
              icon: Icons.auto_awesome_outlined,
              title: 'ИИ-диспетчер',
              onTap: () => open(context, const DispatcherSettingsScreen()),
            ),
            actionCard(
              context,
              icon: Icons.schedule_outlined,
              title: 'Напоминания и системные параметры',
              onTap: () => open(context, const DeveloperConstructorScreen()),
            ),
            actionCard(
              context,
              icon: Icons.receipt_long_outlined,
              title: 'Статьи расходов',
              onTap: () => open(context, const ExpenseCategoriesScreen()),
            ),
          ]),
          const SizedBox(height: 22),
          sectionTitle(context, 'Компания и документы'),
          actionGrid(context, [
            actionCard(
              context,
              icon: Icons.manage_accounts_outlined,
              title: 'Компания и пользователи',
              onTap: () => open(
                context,
                CompanyManagementScreen(companyId: profile.activeCompanyId),
              ),
            ),
            actionCard(
              context,
              icon: Icons.policy_outlined,
              title: 'Работодатель и персональные данные',
              onTap: () =>
                  open(context, CompanyComplianceScreen(profile: profile)),
            ),
            actionCard(
              context,
              icon: Icons.folder_copy_outlined,
              title: 'Шаблоны документов',
              onTap: () =>
                  open(context, TemplateDocumentsScreen(profile: profile)),
            ),
            actionCard(
              context,
              icon: Icons.notifications_none_rounded,
              title: 'Уведомления компании',
              onTap: () =>
                  open(context, const NotificationControlCenterScreen()),
            ),
            actionCard(
              context,
              icon: Icons.devices_rounded,
              title: 'Устройства и push',
              onTap: () =>
                  open(context, const PushNotificationSettingsScreen()),
            ),
            actionCard(
              context,
              icon: Icons.swap_horiz_rounded,
              title: 'Сменить рабочую компанию',
              onTap: () => open(
                context,
                CompanySwitcherScreen(activeCompanyId: profile.activeCompanyId),
              ),
            ),
          ]),
          const SizedBox(height: 22),
          sectionTitle(context, 'Контроль'),
          actionGrid(context, [
            actionCard(
              context,
              icon: Icons.health_and_safety_outlined,
              title: 'Готовность и диагностика',
              onTap: () =>
                  open(context, DeveloperReadinessScreen(profile: profile)),
            ),
            actionCard(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Проверка текущей роли',
              onTap: () => open(
                context,
                DeveloperRoleAcceptanceScreen(profile: profile),
              ),
            ),
            actionCard(
              context,
              icon: Icons.fact_check_outlined,
              title: 'Контроль табеля и выплат',
              onTap: () => open(
                context,
                OperationalAuditLauncherScreen(
                  initialObjectName: profile.objectName,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
