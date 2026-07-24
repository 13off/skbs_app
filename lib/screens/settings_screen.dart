import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../app/theme_controller.dart';
import '../features/archive/presentation/archive_management_screen_v3.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/presentation/company_management_screen.dart';
import '../features/company/presentation/company_setup_screen.dart';
import '../features/company/presentation/company_switcher_screen.dart';
import '../features/developer/presentation/data_governance_screen.dart';
import '../features/developer/presentation/developer_panel_screen.dart';
import '../features/developer/presentation/developer_system_screen.dart';
import '../features/developer/presentation/role_permission_matrix_screen.dart';
import '../features/dispatcher/presentation/dispatcher_settings_screen.dart';
import '../features/legal/presentation/legal_manager_summary_screen.dart';
import '../features/recruitment/presentation/recruitment_crm_settings_screen.dart';
import '../features/role_preview/role_preview_screen.dart';
import '../models/app_user_profile.dart';
import '../services/pwa_install_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';
import 'notification_control_center_screen.dart';
import 'push_notification_settings_screen.dart';
import 'pwa_install_screen.dart';
import 'template_documents_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const SettingsScreen({super.key, required this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<List<CompanySummary>> companiesFuture;

  AppUserProfile get profile => widget.profile;

  @override
  void initState() {
    super.initState();
    companiesFuture = CompanyRepository.fetchMyCompanies();
  }

  void open(Widget screen) {
    Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => screen),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _SettingsActionTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  Widget interfaceSettings() {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return PremiumWorkCard(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text(
                  'Тёмная тема',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: const Text('Применяется ко всем разделам и окнам'),
                value: controller.isDark,
                onChanged: controller.setDark,
              ),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 4),
              const Row(
                children: [
                  Icon(Icons.zoom_out_map_rounded),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Масштаб приложения',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Меняет размер всех разделов, карточек, диалогов и окон.',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemeController.uiScaleOptions.map((value) {
                  final selected = (controller.uiScale - value).abs() < 0.001;
                  return ChoiceChip(
                    selected: selected,
                    label: Text('${(value * 100).round()}%'),
                    onSelected: (_) => controller.setUiScale(value),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget roleInfo({required IconData icon, required String text}) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsIcon(icon: icon),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> roleSettings() {
    if (profile.isHr) {
      return [
        actionTile(
          icon: Icons.view_kanban_outlined,
          title: 'CRM кандидатов',
          subtitle: 'Колонки, поля карточки и автоматические действия',
          onTap: () => open(RecruitmentCrmSettingsScreen(profile: profile)),
        ),
      ];
    }
    if (profile.isDeveloper) {
      return [
        actionTile(
          icon: Icons.monitor_heart_outlined,
          title: 'Состояние системы',
          subtitle: 'Диагностика готовности и системные инструменты',
          onTap: () => open(DeveloperSystemScreen(profile: profile)),
        ),
        actionTile(
          icon: Icons.rule_outlined,
          title: 'Ограничения модулей',
          subtitle: 'Правила объектов, задач, фотографий и редактирования',
          onTap: () => open(DeveloperPanelScreen(profile: profile)),
        ),
        actionTile(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Роли и права',
          subtitle: 'Матрица разрешений профессиональных платформ',
          onTap: () => open(const RolePermissionMatrixScreen()),
        ),
        actionTile(
          icon: Icons.auto_awesome_outlined,
          title: 'ИИ-диспетчер',
          subtitle: 'Расписание, разделы и доставка автоматических сводок',
          onTap: () => open(const DispatcherSettingsScreen()),
        ),
        actionTile(
          icon: Icons.manage_history_outlined,
          title: 'Контроль данных',
          subtitle: 'Диагностика, аудит и управление рабочими данными',
          onTap: () => open(const DataGovernanceScreen()),
        ),
      ];
    }
    if (profile.isForeman) {
      return [
        roleInfo(
          icon: Icons.engineering_outlined,
          text:
              'Правила задач, обязательных фотографий, табеля и сроков задаются для объекта руководителем или разработчиком. Здесь остаются личные настройки прораба.',
        ),
      ];
    }
    if (profile.isAccountant) {
      return [
        roleInfo(
          icon: Icons.account_balance_wallet_outlined,
          text:
              'Правила выплат, согласований и отчётных периодов задаются компанией. Личные уведомления и масштаб меняются в общих разделах.',
        ),
      ];
    }
    if (profile.isLawyer) {
      return [
        actionTile(
          icon: Icons.gavel_rounded,
          title: 'Юридическая сводка',
          subtitle: 'Риски, согласования и решения руководителя',
          onTap: () => open(LegalManagerSummaryScreen(profile: profile)),
        ),
      ];
    }
    return [
      roleInfo(
        icon: Icons.badge_outlined,
        text:
            'Настройки этой профессиональной платформы управляются компанией. Личные параметры доступны в общих разделах.',
      ),
    ];
  }

  List<Widget> companyManagement() {
    if (!profile.isAdmin) return const <Widget>[];
    return [
      actionTile(
        icon: Icons.rocket_launch_outlined,
        title: 'Запуск компании',
        subtitle: 'Объект, сотрудники, первая задача, табель и уведомления',
        onTap: () => open(CompanySetupScreen(profile: profile)),
      ),
      actionTile(
        icon: Icons.manage_accounts_outlined,
        title: 'Компания и пользователи',
        subtitle: 'Приглашения, роли и доступ пользователей компании',
        onTap: () => open(
          CompanyManagementScreen(companyId: profile.activeCompanyId),
        ),
      ),
      actionTile(
        icon: Icons.gavel_rounded,
        title: 'Юридическая сводка',
        subtitle: 'Риски, согласования и недельный отчёт юриста',
        onTap: () => open(LegalManagerSummaryScreen(profile: profile)),
      ),
      actionTile(
        icon: Icons.inventory_2_outlined,
        title: 'Архив и удаление',
        subtitle: 'Восстановление и окончательное удаление рабочих данных',
        onTap: () => open(ArchiveManagementScreenV3(profile: profile)),
      ),
      actionTile(
        icon: Icons.folder_copy_outlined,
        title: 'Шаблоны документов',
        subtitle: 'Исходники, версии и загрузка утверждённых форм',
        onTap: () => open(TemplateDocumentsScreen(profile: profile)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final roleItems = roleSettings();
    final managementItems = companyManagement();
    return AppPage(
      title: 'Настройки',
      subtitle: 'Общие параметры и настройки роли «${profile.roleTitle}»',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionTitle('Интерфейс'),
          interfaceSettings(),
          const SizedBox(height: 18),
          sectionTitle('Уведомления'),
          if (profile.isAdmin)
            actionTile(
              icon: Icons.tune_rounded,
              title: 'Правила уведомлений компании',
              subtitle: 'Роли, типы событий и встроенные напоминания',
              onTap: () => open(const NotificationControlCenterScreen()),
            ),
          actionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push-уведомления',
            subtitle: 'Разрешение и регистрация этого устройства',
            onTap: () => open(const PushNotificationSettingsScreen()),
          ),
          const SizedBox(height: 8),
          sectionTitle('Настройки профессии'),
          ...roleItems,
          if (managementItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            sectionTitle('Управление компанией'),
            ...managementItems,
          ],
          if (profile.canPreviewRoles) ...[
            const SizedBox(height: 8),
            sectionTitle('Профессиональная платформа'),
            actionTile(
              icon: Icons.switch_account_rounded,
              title: 'Переключить платформу',
              subtitle: 'Посмотреть приложение от имени другой профессии',
              onTap: () => open(const RolePreviewScreen()),
            ),
          ],
          const SizedBox(height: 8),
          sectionTitle('Приложение и рабочее пространство'),
          if (PwaInstallService.isSupported)
            actionTile(
              icon: Icons.install_desktop_rounded,
              title: 'Установить AppСтрой',
              subtitle: 'Добавить на телефон или компьютер как приложение',
              onTap: () => open(const PwaInstallScreen()),
            ),
          FutureBuilder<List<CompanySummary>>(
            future: companiesFuture,
            builder: (context, snapshot) {
              final companies = snapshot.data ?? const <CompanySummary>[];
              if (companies.length < 2) return const SizedBox.shrink();
              return actionTile(
                icon: Icons.swap_horiz_rounded,
                title: 'Сменить компанию',
                subtitle: 'Переключиться между рабочими пространствами',
                onTap: () => open(
                  CompanySwitcherScreen(
                    activeCompanyId: profile.activeCompanyId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              _SettingsIcon(icon: icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;

  const _SettingsIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: scheme.onSurfaceVariant, size: 21),
    );
  }
}
