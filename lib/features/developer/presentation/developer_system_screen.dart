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
import '../../company/presentation/company_setup_screen.dart';
import '../../compliance/presentation/company_compliance_screen.dart';
import 'developer_constructor_screen.dart';
import 'developer_readiness_screen.dart';
import 'developer_role_acceptance_screen.dart';

class DeveloperSystemScreen extends StatelessWidget {
  final AppUserProfile profile;

  const DeveloperSystemScreen({super.key, required this.profile});

  void open(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute<void>(builder: (_) => screen));
  }

  Widget statusCard(BuildContext context) {
    return const PremiumWorkCard(
      radius: 28,
      padding: EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.developer_board_rounded, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Системные настройки',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Здесь собраны настройки, которые влияют на работу всей компании. '
            'Фактическое состояние базы, прав и серверных функций показывается '
            'только после запуска диагностики — статические статусы здесь не используются.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
        ],
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
      title: 'Система',
      showBackButton: true,
      subtitle: 'Общие настройки AppСтрой без правок в коде',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusCard(context),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              'КОНТРОЛЬ И ПРИЁМКА',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
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
            icon: Icons.rocket_launch_outlined,
            title: 'Запуск компании',
            subtitle:
                'Проверить первый объект, назначенного прораба, сотрудников, задачу, табель и уведомления.',
            onTap: () => open(context, CompanySetupScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.verified_user_outlined,
            title: 'Проверка текущей роли',
            subtitle:
                'Проверить JWT, разрешения, Data API и объектные границы только текущего входа — без имитации других ролей.',
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
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Text(
              'СИСТЕМНЫЕ РАЗДЕЛЫ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          actionCard(
            context,
            icon: Icons.policy_outlined,
            title: 'Работодатель и персональные данные',
            subtitle:
                'Заполнить юридические реквизиты, утвердить формы и управлять серверным production gate.',
            onTap: () =>
                open(context, CompanyComplianceScreen(profile: profile)),
          ),
          actionCard(
            context,
            icon: Icons.schedule_outlined,
            title: 'Напоминания и системные параметры',
            subtitle:
                'Настраивать расписание уведомлений и технические параметры. Ограничения задач находятся только в отдельной вкладке «Ограничения».',
            onTap: () => open(context, const DeveloperConstructorScreen()),
          ),
          actionCard(
            context,
            icon: Icons.notifications_none_rounded,
            title: 'Уведомления и напоминания',
            subtitle:
                'Базовые роли, события, колокольчик, push и встроенные напоминания.',
            onTap: () => open(context, const NotificationControlCenterScreen()),
          ),
          actionCard(
            context,
            icon: Icons.devices_rounded,
            title: 'Устройства и push',
            subtitle:
                'Регистрация текущего телефона или браузера и диагностика доставки.',
            onTap: () => open(context, const PushNotificationSettingsScreen()),
          ),
          actionCard(
            context,
            icon: Icons.manage_accounts_outlined,
            title: 'Роли и пользователи',
            subtitle:
                'Приглашения, профессии, доступ и отключение пользователей компании.',
            onTap: () => open(
              context,
              CompanyManagementScreen(companyId: profile.activeCompanyId),
            ),
          ),
          actionCard(
            context,
            icon: Icons.folder_copy_outlined,
            title: 'Шаблоны документов',
            subtitle: 'Системные формы договоров, актов и кадровых документов.',
            onTap: () =>
                open(context, TemplateDocumentsScreen(profile: profile)),
          ),
        ],
      ),
    );
  }
}
