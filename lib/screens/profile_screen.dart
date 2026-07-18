import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../app/theme_controller.dart';
import '../data/user_repository.dart';
import '../features/archive/presentation/archive_management_screen_v3.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/presentation/company_management_screen.dart';
import '../features/company/presentation/company_switcher_screen.dart';
import '../features/developer/presentation/developer_panel_screen.dart';
import '../features/legal/presentation/legal_manager_summary_screen.dart';
import '../features/role_preview/role_preview_controller.dart';
import '../features/role_preview/role_preview_screen.dart';
import '../models/app_user_profile.dart';
import '../services/pwa_install_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';
import 'notification_control_center_screen.dart';
import 'push_notification_settings_screen.dart';
import 'pwa_install_screen.dart';
import 'template_documents_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppUserProfile profile;

  const ProfileScreen({super.key, required this.profile});

  Future<void> signOut(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'После выхода нужно будет снова ввести логин и пароль.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (shouldExit != true) return;
    RolePreviewController.reset();
    await UserRepository.signOut();
  }

  void openTemplateDocuments(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const TemplateDocumentsScreen()),
    );
  }

  void openArchive(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => ArchiveManagementScreenV3(profile: profile),
      ),
    );
  }

  void openCompanyManagement(BuildContext context) {
    if (profile.activeCompanyId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            CompanyManagementScreen(companyId: profile.activeCompanyId),
      ),
    );
  }

  void openCompanySwitcher(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) =>
            CompanySwitcherScreen(activeCompanyId: profile.activeCompanyId),
      ),
    );
  }

  void openPushSettings(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const PushNotificationSettingsScreen(),
      ),
    );
  }

  void openNotificationControlCenter(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => const NotificationControlCenterScreen(),
      ),
    );
  }

  void openPwaInstall(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const PwaInstallScreen()),
    );
  }

  void openLegalSummary(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => LegalManagerSummaryScreen(profile: profile),
      ),
    );
  }

  void openRolePreview(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const RolePreviewScreen()),
    );
  }

  void openDeveloperPanel(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => DeveloperPanelScreen(profile: profile),
      ),
    );
  }

  String get profileInitial {
    final words = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'A';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
        .toUpperCase();
  }

  String get roleDescription {
    if (!profile.isRolePreview) return profile.roleTitle;
    return '${profile.roleTitle} · просмотр администратора';
  }

  Widget buildThemeToggle() {
    final controller = AppThemeController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isDark = controller.isDark;
        return IconButton(
          tooltip: isDark ? 'Включить светлую тему' : 'Включить тёмную тему',
          onPressed: controller.toggle,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: 0.84, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              key: ValueKey<bool>(isDark),
            ),
          ),
        );
      },
    );
  }

  Widget buildProfileHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      radius: 28,
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF73777C), Color(0xFF34373B)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              profileInitial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isEmpty
                      ? 'Пользователь AppСтрой'
                      : profile.fullName,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  roleDescription,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              profile.isRolePreview
                  ? Icons.visibility_outlined
                  : Icons.verified_user_outlined,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
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

  Widget buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _TileIcon(icon: icon),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? 'Не указано' : value,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
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

  Widget buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              _TileIcon(icon: icon),
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
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSignOutButton(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumPressable(
      onTap: () => signOut(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: scheme.onSurface, size: 20),
            const SizedBox(width: 9),
            Text(
              'Выйти',
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
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
      title: 'Профиль',
      subtitle: 'Аккаунт, компания и доступ к рабочим инструментам',
      headerTrailing: buildThemeToggle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildProfileHero(context),
          const SizedBox(height: 18),
          if (profile.canPreviewRoles) ...[
            buildSectionTitle(context, 'Режим платформы'),
            buildActionTile(
              context,
              icon: Icons.switch_account_rounded,
              title: 'Переключить платформу',
              subtitle:
                  'Сейчас: ${profile.roleTitle}. Открыть платформу руководителя, прораба или юриста',
              onTap: () => openRolePreview(context),
            ),
            const SizedBox(height: 8),
          ],
          buildSectionTitle(context, 'Рабочие данные'),
          if (profile.activeCompanyId.isNotEmpty)
            FutureBuilder<CompanySummary>(
              future: CompanyRepository.fetchCompany(profile.activeCompanyId),
              builder: (context, snapshot) => buildInfoTile(
                context,
                icon: Icons.apartment_rounded,
                title: 'Компания',
                value:
                    snapshot.data?.name ??
                    (snapshot.hasError ? 'Не удалось загрузить' : 'Загрузка...'),
              ),
            ),
          buildInfoTile(
            context,
            icon: Icons.person_outline,
            title: 'ФИО',
            value: profile.fullName,
          ),
          buildInfoTile(
            context,
            icon: Icons.work_outline_rounded,
            title: 'Профессия',
            value: profile.profession,
          ),
          buildInfoTile(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: profile.isRolePreview ? 'Открытая платформа' : 'Роль',
            value: roleDescription,
          ),
          buildInfoTile(
            context,
            icon: Icons.email_outlined,
            title: 'Email',
            value: profile.email,
          ),
          buildInfoTile(
            context,
            icon: Icons.apartment_outlined,
            title: 'Объект',
            value: profile.objectName,
          ),
          const SizedBox(height: 8),
          buildSectionTitle(context, 'Уведомления'),
          if (profile.isAdmin)
            buildActionTile(
              context,
              icon: Icons.tune_rounded,
              title: 'Настройка уведомлений',
              subtitle:
                  'Колокольчик, push, роли, типы событий и все напоминания компании',
              onTap: () => openNotificationControlCenter(context),
            ),
          buildActionTile(
            context,
            icon: Icons.notifications_active_outlined,
            title: 'Push-уведомления',
            subtitle:
                'Разрешение, регистрация телефона или браузера и отключение устройства',
            onTap: () => openPushSettings(context),
          ),
          if (PwaInstallService.isSupported) ...[
            const SizedBox(height: 8),
            buildSectionTitle(context, 'Приложение'),
            buildActionTile(
              context,
              icon: Icons.install_desktop_rounded,
              title: 'Установить AppСтрой',
              subtitle:
                  'Добавить на телефон или компьютер как отдельное приложение',
              onTap: () => openPwaInstall(context),
            ),
          ],
          const SizedBox(height: 8),
          if (profile.isAdmin) ...[
            buildSectionTitle(context, 'Для разработчика'),
            buildActionTile(
              context,
              icon: Icons.developer_mode_rounded,
              title: 'Панель разработчика',
              subtitle:
                  'Ограничения компании и объектов, наследование правил и журнал изменений',
              onTap: () => openDeveloperPanel(context),
            ),
            const SizedBox(height: 8),
            buildSectionTitle(context, 'Управление компанией'),
            buildActionTile(
              context,
              icon: Icons.gavel_rounded,
              title: 'Юридическая сводка',
              subtitle:
                  'Риски, согласования, решения руководителя и недельный отчёт юриста',
              onTap: () => openLegalSummary(context),
            ),
            buildActionTile(
              context,
              icon: Icons.manage_accounts_outlined,
              title: 'Компания и пользователи',
              subtitle:
                  'Приглашения, роли и доступ всех пользователей компании',
              onTap: () => openCompanyManagement(context),
            ),
            buildActionTile(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Архив и удаление',
              subtitle:
                  'Архивированные сотрудники и объекты: восстановить или удалить навсегда',
              onTap: () => openArchive(context),
            ),
            buildActionTile(
              context,
              icon: Icons.folder_copy_outlined,
              title: 'Документы',
              subtitle: 'Шаблоны договоров, КС-2, КС-3 и другие формы',
              onTap: () => openTemplateDocuments(context),
            ),
            const SizedBox(height: 8),
          ],
          FutureBuilder<List<CompanySummary>>(
            future: CompanyRepository.fetchMyCompanies(),
            builder: (context, snapshot) {
              final companies = snapshot.data ?? const <CompanySummary>[];
              if (companies.length < 2) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSectionTitle(context, 'Рабочее пространство'),
                  buildActionTile(
                    context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Сменить компанию',
                    subtitle:
                        'Переключиться между доступными рабочими пространствами',
                    onTap: () => openCompanySwitcher(context),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
          buildSignOutButton(context),
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  final IconData icon;

  const _TileIcon({required this.icon});

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
      child: Icon(icon, color: scheme.onSurface, size: 21),
    );
  }
}
