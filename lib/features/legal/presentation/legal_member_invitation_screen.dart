import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/company/data/company_repository.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';

class LegalMemberInvitationScreen extends StatefulWidget {
  final String companyId;

  const LegalMemberInvitationScreen({super.key, required this.companyId});

  @override
  State<LegalMemberInvitationScreen> createState() =>
      _LegalMemberInvitationScreenState();
}

class _LegalMemberInvitationScreenState
    extends State<LegalMemberInvitationScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  String role = 'lawyer';
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> invite() async {
    if (saving) return;
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    if (name.length < 2 || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите имя и корректный email')),
      );
      return;
    }
    setState(() => saving = true);
    try {
      final result = await CompanyRepository.inviteMember(
        companyId: widget.companyId,
        fullName: name,
        email: email,
        role: role,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ссылка приглашения готова'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Получатель: $email'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(result.inviteUrl),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.inviteUrl));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Копировать'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пригласить специалиста')),
      body: AppPage(
        title: 'Новый специалист',
        subtitle: 'Юрист или бухгалтер получает отдельный рабочий раздел без доступа к лишним данным',
        child: PremiumWorkCard(
          radius: 26,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              TextField(
                controller: nameController,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Имя и фамилия',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                enabled: !saving,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'Роль',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'lawyer', child: Text('Юрист')),
                  DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => role = value ?? 'lawyer'),
              ),
              const SizedBox(height: 22),
              PremiumActionButton(
                label: 'Создать ссылку',
                icon: Icons.link_rounded,
                onPressed: saving ? null : invite,
                isLoading: saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
