import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/company_repository.dart';

Future<void> showDesktopInvitationLink(
  BuildContext context, {
  required CompanyInviteResult result,
  required String email,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ссылка приглашения готова'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.requiresPasswordSetup
                  ? 'Пользователь откроет ссылку, войдёт в компанию и задаст пароль.'
                  : 'Пользователь уже зарегистрирован. Ссылка выполнит безопасный вход в компанию.',
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Получатель: $email',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: specialistSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: specialistLine),
              ),
              child: SelectableText(
                result.inviteUrl,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Старая активная ссылка для этого email автоматически отменена. Передайте новую ссылку только приглашённому человеку.',
              style: TextStyle(
                color: specialistMuted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Готово'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: result.inviteUrl));
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Ссылка скопирована')));
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Копировать'),
        ),
      ],
    ),
  );
}

class DesktopCompanyMemberDialog extends StatefulWidget {
  final String companyId;
  final List<CompanyObject> objects;
  final CompanyMember? member;

  const DesktopCompanyMemberDialog({
    super.key,
    required this.companyId,
    required this.objects,
    this.member,
  });

  @override
  State<DesktopCompanyMemberDialog> createState() =>
      _DesktopCompanyMemberDialogState();
}

class _DesktopCompanyMemberDialogState
    extends State<DesktopCompanyMemberDialog> {
  late final TextEditingController fullNameController;
  late final TextEditingController emailController;
  late String role;
  String? objectId;
  bool isSaving = false;
  String? errorText;

  bool get isEditing => widget.member != null;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController(
      text: widget.member?.fullName ?? '',
    );
    emailController = TextEditingController(text: widget.member?.email ?? '');
    const roles = <String>{'admin', 'foreman', 'lawyer', 'accountant', 'hr'};
    final currentRole = widget.member?.role;
    role = currentRole != null && roles.contains(currentRole)
        ? currentRole
        : 'foreman';
    objectId = role == 'foreman'
        ? (widget.member?.objectId.isNotEmpty == true
              ? widget.member!.objectId
              : (widget.objects.isEmpty ? null : widget.objects.first.id))
        : null;
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    super.dispose();
  }

  void changeRole(String nextRole) {
    setState(() {
      role = nextRole;
      if (role != 'foreman') {
        objectId = null;
        return;
      }
      final available = widget.objects.any((object) => object.id == objectId);
      if (!available) {
        objectId = widget.objects.isEmpty ? null : widget.objects.first.id;
      }
    });
  }

  Future<void> save() async {
    if (isSaving) return;
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    if (!isEditing && (fullName.length < 2 || !email.contains('@'))) {
      setState(() => errorText = 'Укажите имя и корректный email');
      return;
    }
    if (role == 'foreman' && (objectId == null || objectId!.isEmpty)) {
      setState(() => errorText = 'Для прораба нужно выбрать объект');
      return;
    }

    setState(() {
      isSaving = true;
      errorText = null;
    });
    try {
      if (isEditing) {
        await CompanyRepository.updateMemberAccess(
          companyId: widget.companyId,
          member: widget.member!,
          role: role,
          objectId: role == 'foreman' ? objectId : null,
        );
        if (mounted) Navigator.pop(context, 'Права пользователя обновлены');
      } else {
        final result = await CompanyRepository.inviteMember(
          companyId: widget.companyId,
          fullName: fullName,
          email: email,
          role: role,
          objectId: role == 'foreman' ? objectId : null,
        );
        if (!mounted) return;
        await showDesktopInvitationLink(context, result: result, email: email);
        if (!mounted) return;
        Navigator.pop(
          context,
          result.existingUser
              ? 'Новая ссылка входа создана'
              : 'Приглашение создано',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> removeMember() async {
    if (!isEditing || isSaving) return;
    final member = widget.member!;
    final title = member.fullName.trim().isEmpty
        ? member.email
        : member.fullName.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmationContext) => AlertDialog(
        title: const Text('Удалить пользователя из компании?'),
        content: Text(
          '$title потеряет доступ к этой компании и назначенному объекту. Аккаунт и доступ к другим компаниям сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: specialistDanger),
            onPressed: () => Navigator.pop(confirmationContext, true),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      isSaving = true;
      errorText = null;
    });
    try {
      await CompanyRepository.removeMember(
        companyId: widget.companyId,
        member: member,
      );
      if (mounted) Navigator.pop(context, 'Пользователь удалён из компании');
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Права пользователя'
                          : 'Пригласить пользователя',
                      style: const TextStyle(
                        color: specialistText,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isEditing
                    ? 'Измените роль и назначенный объект.'
                    : 'Одна форма для администратора, прораба, юриста, бухгалтера и HR.',
                style: const TextStyle(
                  color: specialistMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (!isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fullNameController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'Имя и фамилия',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        enabled: !isSaving,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: specialistSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: specialistLine),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.member!.fullName.trim().isEmpty
                                  ? widget.member!.email
                                  : widget.member!.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              widget.member!.email,
                              style: const TextStyle(color: specialistMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(
                        labelText: 'Роль',
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'admin',
                          child: Text('Администратор'),
                        ),
                        DropdownMenuItem(
                          value: 'foreman',
                          child: Text('Прораб'),
                        ),
                        DropdownMenuItem(value: 'lawyer', child: Text('Юрист')),
                        DropdownMenuItem(
                          value: 'accountant',
                          child: Text('Бухгалтер'),
                        ),
                        DropdownMenuItem(
                          value: 'hr',
                          child: Text('HR-менеджер'),
                        ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) => changeRole(value ?? 'foreman'),
                    ),
                  ),
                  if (role == 'foreman') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            widget.objects.any(
                              (object) => object.id == objectId,
                            )
                            ? objectId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Объект',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: widget.objects
                            .map(
                              (object) => DropdownMenuItem<String>(
                                value: object.id,
                                child: Text(
                                  object.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) => setState(() => objectId = value),
                      ),
                    ),
                  ],
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 14),
                Text(
                  errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: specialistDanger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  if (isEditing) ...[
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: specialistDanger,
                      ),
                      onPressed: isSaving ? null : removeMember,
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Удалить из компании'),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: isSaving ? null : save,
                    icon: isSaving
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isEditing ? Icons.save_outlined : Icons.link),
                    label: Text(
                      isEditing ? 'Сохранить права' : 'Создать ссылку',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
