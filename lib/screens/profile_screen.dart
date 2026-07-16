import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../data/user_repository.dart';
import '../features/archive/presentation/archive_management_screen_v3.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/presentation/company_management_screen.dart';
import '../features/company/presentation/company_switcher_screen.dart';
import '../features/legal/presentation/legal_manager_summary_screen.dart';
import '../features/legal/presentation/legal_member_invitation_screen.dart';
import '../features/role_preview/role_preview_controller.dart';
import '../features/role_preview/role_preview_screen.dart';
import '../models/app_user_profile.dart';
import '../services/pwa_install_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';
import 'push_notification_settings_screen.dart';
import 'pwa_install_screen.dart';
import 'template_documents_screen.dart';

const Color _profileText = Color(0xFF1F2328);
const Color _profileMuted = Color(0xFF6B7075);
const Color _profileSoft = Color(0xFFF1F0EC);
const Color _profileLine = Color(0xFFE4E2DC);

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
        builder: (_) => CompanyManagementScreen(
          companyId: profile.activeCompanyId,
        ),
      ),
    );
  }

  void openCompanySwitcher(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CompanySwitcherScreen(
          activeCompanyId: profile.activeCompanyId,
        ),
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

  void openPwaInstall(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const PwaInstallScreen()),
    );
  }

  void openSpecialistInvitation(BuildContext context) {
    if (profile.activeCompanyId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => LegalMemberInvitationScreen(
          companyId: profile.activeCompanyId,
        ),
      ),
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

  Widget buildProfileHero() {
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
                  color: const Color(0xFF17191C).withValues(alpha: 0.18),
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
                  style: const TextStyle(
                    color: _profileText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  roleDescription,
                  style: const TextStyle(
                    color: _profileMuted,
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
              color: _profileSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              profile.isRolePreview
                  ? Icons.visibility_outlined
                  : Icons.verified_user_outlined,
              color: _profileMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: _profileMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
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
                    style: const TextStyle(
                      color: _profileMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? 'Не указано' : value,
                    style: const TextStyle(
                      color: _profileText,
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

  Widget buildActionTile({
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
                      style: const TextStyle(
                        color: _profileText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _profileMuted,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _profileMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSignOutButton(BuildContext context) {
    return PremiumPressable(
      onTap: () => signOut(context),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _profileLine),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _profileText, size: 20),
            SizedBox(width: 9),
            Text(
              'Выйти',
              style: TextStyle(
                color: _profileText,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildProfileHero(),
          const SizedBox(height: 18),
          if (profile.canPreviewRoles) ...[
            buildSectionTitle('Режим платформы'),
            buildActionTile(
              icon: Icons.switch_account_rounded,
              title: 'Переключить платформу',
              subtitle:
                  'Сейчас: ${profile.roleTitle}. Открыть платформу руководителя, прораба или юриста',
              onTap: () => openRolePreview(context),
            ),
            const SizedBox(height: 8),
          ],
          buildSectionTitle('Рабочие данные'),
          if (profile.activeCompanyId.isNotEmpty)
            FutureBuilder<CompanySummary>(
              future: CompanyRepository.fetchCompany(profile.activeCompanyId),
              builder: (context, snapshot) => buildInfoTile(
                icon: Icons.apartment_rounded,
                title: 'Компания',
                value: snapshot.data?.name ??
                    (snapshot.hasError ? 'Не удалось загрузить' : 'Загрузка...'),
              ),
            ),
          buildInfoTile(
            icon: Icons.person_outline,
            title: 'ФИО',
            value: profile.fullName,
          ),
          buildInfoTile(
            icon: Icons.admin_panel_settings_outlined,
            title: profile.isRolePreview ? 'Открытая платформа' : 'Роль',
            value: roleDescription,
          ),
          buildInfoTile(
            icon: Icons.email_outlined,
            title: 'Email',
            value: profile.email,
          ),
          buildInfoTile(
            icon: Icons.apartment_outlined,
            title: 'Объект',
            value: profile.objectName,
          ),
          const SizedBox(height: 8),
          buildSectionTitle('Уведомления'),
          buildActionTile(
            icon: Icons.notifications_active_outlined,
            title: 'Push-уведомления',
            subtitle:
                'Разрешение, регистрация телефона или браузера и отключение устройства',
            onTap: () => openPushSettings(context),
          ),
          if (PwaInstallService.isSupported) ...[
            const SizedBox(height: 8),
            buildSectionTitle('Приложение'),
            buildActionTile(
              icon: Icons.install_desktop_rounded,
              title: 'Установить AppСтрой',
              subtitle:
                  'Добавить на телефон или компьютер как отдельное приложение',
              onTap: () => openPwaInstall(context),
            ),
          ],
          const SizedBox(height: 8),
          if (profile.isAdmin) ...[
            buildSectionTitle('Управление компанией'),
            buildActionTile(
              icon: Icons.gavel_rounded,
              title: 'Юридическая сводка',
              subtitle:
                  'Риски, согласования, решения руководителя и недельный отчёт юриста',
              onTap: () => openLegalSummary(context),
            ),
            buildActionTile(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Пригласить юриста или бухгалтера',
              subtitle:
                  'Создать ссылку для специалиста с отдельной ролью и рабочим разделом',
              onTap: () => openSpecialistInvitation(context),
            ),
            buildActionTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Компания и пользователи',
              subtitle:
                  'Приглашения, роли администраторов и назначение прорабов',
              onTap: () => openCompanyManagement(context),
            ),
            buildActionTile(
              icon: Icons.inventory_2_outlined,
              title: 'Архив и удаление',
              subtitle:
                  'Архивированные сотрудники и объекты: восстановить или удалить навсегда',
              onTap: () => openArchive(context),
            ),
            buildActionTile(
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
                  buildSectionTitle('Рабочее пространство'),
                  buildActionTile(
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
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _profileSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: _profileText, size: 21),
    );
  }
}
