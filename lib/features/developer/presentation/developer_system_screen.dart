import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
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
import 'role_permission_matrix_screen.dart';

class DeveloperSystemScreen extends StatelessWidget {
  final AppUserProfile profile;

  const DeveloperSystemScreen({super.key, required this.profile});

  void open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => screen));
  }

  Widget constructorCard(BuildContext context) {
    final companySelected = profile.activeCompanyId.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.dashboard_customize_rounded),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Конструктор текущей компании',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            companySelected
                ? 'Все изменения относятся только к выбранной компании. Общие правила наследуются объектами, а исключения создаются внутри уже действующих редакторов.'
                : 'Сначала выберите рабочую компанию. Без активной компании системные настройки не сохраняются.',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ArchitectureBadge(
                icon: Icons.apartment_rounded,
                label: 'Компания',
              ),
              _ArchitectureArrow(),
              _ArchitectureBadge(
                icon: Icons.account_tree_outlined,
                label: 'Объект',
              ),
              _ArchitectureArrow(),
              _ArchitectureBadge(icon: Icons.badge_outlined, label: 'Роль'),
            ],
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(BuildContext context, String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 5, 4, 10),
      child: Text(
        value.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
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

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Конструктор',
      subtitle: 'Конфигурация текущей компании без второго механизма настроек',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          constructorCard(context),
          const SizedBox(height: 18),
          sectionTitle(context, 'Логика приложения'),
          actionCard(
            context,
            icon: Icons.rule_outlined,
            title: 'Ограничения задач и объектов',
            subtitle:
                'Фотографии, даты, редактирование, исполнители и удаление. Компания задаёт основу, объект — исключение.',
            onTap: () => open(context, DeveloperPanelScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: 'Роли и права',
            subtitle:
                'Единая матрица разрешений с наследованием стандарт роли → компания → объект.',
            onTap: () => open(context, const RolePermissionMatrixScreen()),
          ),
          actionCard(
            context,
            icon: Icons.auto_awesome_outlined,
            title: 'ИИ-диспетчер',
            subtitle:
                'Состав автоматических сводок, расписание и доставка по действующим ролям.',
            onTap: () => open(context, const DispatcherSettingsScreen()),
          ),
          actionCard(
            context,
            icon: Icons.schedule_outlined,
            title: 'Напоминания и системные параметры',
            subtitle:
                'Рабочие расписания и технические значения текущей компании. Ограничения и права здесь не дублируются.',
            onTap: () => open(context, const DeveloperConstructorScreen()),
          ),
          const SizedBox(height: 8),
          sectionTitle(context, 'Состав компании и документы'),
          actionCard(
            context,
            icon: Icons.manage_accounts_outlined,
            title: 'Компания и пользователи',
            subtitle:
                'Приглашения, профессии, роли, объектный доступ и отключение пользователей.',
            onTap: () => open(
              context,
              CompanyManagementScreen(companyId: profile.activeCompanyId),
            ),
          ),
          actionCard(
            context,
            icon: Icons.policy_outlined,
            title: 'Работодатель и персональные данные',
            subtitle:
                'Юридические реквизиты, утверждённые формы и серверный production gate.',
            onTap: () =>
                open(context, CompanyComplianceScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.folder_copy_outlined,
            title: 'Шаблоны документов',
            subtitle:
                'Системные формы договоров, актов и кадровых документов текущей компании.',
            onTap: () =>
                open(context, TemplateDocumentsScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Уведомления компании',
            subtitle:
                'Базовые роли, события, колокольчик, push и встроенные напоминания.',
            onTap: () => open(context, const NotificationControlCenterScreen()),
          ),
          actionCard(
            context,
            icon: Icons.devices_rounded,
            title: 'Устройства и push',
            subtitle:
                'Регистрация текущего браузера или телефона и диагностика доставки.',
            onTap: () => open(context, const PushNotificationSettingsScreen()),
          ),
          actionCard(
            context,
            icon: Icons.swap_horiz_rounded,
            title: 'Сменить рабочую компанию',
            subtitle:
                'Переключить контекст перед настройкой другой организации. Правила между компаниями не смешиваются.',
            onTap: () => open(
              context,
              CompanySwitcherScreen(activeCompanyId: profile.activeCompanyId),
            ),
          ),
          const SizedBox(height: 8),
          sectionTitle(context, 'Контроль и приёмка'),
          actionCard(
            context,
            icon: Icons.health_and_safety_outlined,
            title: 'Готовность и диагностика',
            subtitle:
                'Проверить сессию, RLS, базу, ограничения, шаблоны, Edge Function и production-gates.',
            onTap: () =>
                open(context, DeveloperReadinessScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Проверка текущей роли',
            subtitle:
                'Проверить JWT, разрешения, Data API и объектные границы фактического входа.',
            onTap: () =>
                open(context, DeveloperRoleAcceptanceScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.fact_check_outlined,
            title: 'Контроль табеля и выплат',
            subtitle:
                'Запустить единый read-only аудит месяца и объекта без команды в ИИ-чате.',
            onTap: () => open(
              context,
              OperationalAuditLauncherScreen(
                initialObjectName: profile.objectName,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchitectureBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ArchitectureBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ArchitectureArrow extends StatelessWidget {
  const _ArchitectureArrow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
