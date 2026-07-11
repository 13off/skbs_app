import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;

import '../data/user_repository.dart';
import '../features/archive/presentation/archive_management_screen_v3.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/presentation/company_management_screen.dart';
import '../features/company/presentation/company_switcher_screen.dart';
import '../models/app_user_profile.dart';
import '../widgets/app_page.dart';
import 'template_documents_screen.dart';

class ProfileScreen extends StatelessWidget {
  final AppUserProfile profile;

  const ProfileScreen({super.key, required this.profile});

  Future<void> signOut(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text(
            'После выхода нужно будет снова ввести логин и пароль.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (shouldExit != true) return;

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

  Widget buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value.isEmpty ? 'Не указано' : value,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 0,
      color: color ?? const Color(0xFFF0EFEB),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Профиль',
      subtitle: 'Пользователь системы',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.activeCompanyId.isNotEmpty)
            FutureBuilder<CompanySummary>(
              future: CompanyRepository.fetchCompany(profile.activeCompanyId),
              builder: (context, snapshot) {
                return buildInfoTile(
                  icon: Icons.apartment_rounded,
                  title: 'Компания',
                  value: snapshot.data?.name ??
                      (snapshot.hasError ? 'Не удалось загрузить' : 'Загрузка...'),
                );
              },
            ),
          buildInfoTile(
            icon: Icons.person_outline,
            title: 'ФИО',
            value: profile.fullName,
          ),
          buildInfoTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Роль',
            value: profile.roleTitle,
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

          const SizedBox(height: 12),

          if (profile.isAdmin) ...[
            buildActionTile(
              icon: Icons.manage_accounts_outlined,
              title: 'Компания и пользователи',
              subtitle:
                  'Приглашения, роли администраторов и назначение прорабов',
              onTap: () {
                openCompanyManagement(context);
              },
            ),
            const SizedBox(height: 10),
            buildActionTile(
              icon: Icons.inventory_2_outlined,
              title: 'Архив и удаление',
              subtitle:
                  'Архивированные сотрудники и объекты: восстановить или удалить навсегда',
              color: const Color(0xFFF0EFEB),
              onTap: () {
                openArchive(context);
              },
            ),
            const SizedBox(height: 10),
            buildActionTile(
              icon: Icons.folder_copy_outlined,
              title: 'Документы',
              subtitle: 'Шаблоны договоров, КС-2, КС-3 и другие формы',
              onTap: () {
                openTemplateDocuments(context);
              },
            ),

            const SizedBox(height: 18),
          ],

          FutureBuilder<List<CompanySummary>>(
            future: CompanyRepository.fetchMyCompanies(),
            builder: (context, snapshot) {
              final companies = snapshot.data ?? const <CompanySummary>[];
              if (companies.length < 2) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: buildActionTile(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Сменить компанию',
                  subtitle: 'Переключиться между доступными рабочими пространствами',
                  onTap: () {
                    openCompanySwitcher(context);
                  },
                ),
              );
            },
          ),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () {
                signOut(context);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Выйти'),
            ),
          ),
        ],
      ),
    );
  }
}
