import 'package:flutter/material.dart';

import '../data/user_repository.dart';
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
      MaterialPageRoute(builder: (_) => const TemplateDocumentsScreen()),
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
  }) {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFEEE7),
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
              icon: Icons.folder_copy_outlined,
              title: 'Документы',
              subtitle: 'Шаблоны договоров, КС-2, КС-3 и другие формы',
              onTap: () {
                openTemplateDocuments(context);
              },
            ),

            const SizedBox(height: 18),
          ],

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
