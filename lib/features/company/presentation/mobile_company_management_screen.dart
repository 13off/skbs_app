import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/company_repository.dart';
import 'company_plans_screen.dart';

class CompanyManagementScreen extends StatefulWidget {
  final String companyId;

  const CompanyManagementScreen({super.key, required this.companyId});

  @override
  State<CompanyManagementScreen> createState() =>
      _CompanyManagementScreenState();
}

class _CompanyManagementScreenState extends State<CompanyManagementScreen> {
  late Future<CompanyDashboard> dashboardFuture;

  @override
  void initState() {
    super.initState();
    dashboardFuture = CompanyRepository.fetchDashboard(widget.companyId);
  }

  Future<void> refresh() async {
    final future = CompanyRepository.fetchDashboard(widget.companyId);
    setState(() => dashboardFuture = future);
    await future;
  }

  Future<void> openInvite(CompanyDashboard dashboard) async {
    final result = await Navigator.push<String>(
      context,
      CupertinoPageRoute(
        builder: (_) => CompanyMemberEditorScreen(
          companyId: widget.companyId,
          objects: dashboard.objects,
        ),
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    await refresh();
  }

  Future<void> editMember(
    CompanyDashboard dashboard,
    CompanyMember member,
  ) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (member.isOwner || member.userId == currentUserId) return;

    final result = await Navigator.push<String>(
      context,
      CupertinoPageRoute(
        builder: (_) => CompanyMemberEditorScreen(
          companyId: widget.companyId,
          objects: dashboard.objects,
          member: member,
        ),
      ),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    await refresh();
  }

  void openPlans(CompanyDashboard dashboard) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => CompanyPlansScreen(dashboard: dashboard),
      ),
    );
  }

  String planTitle(CompanySummary company) {
    switch (company.planCode) {
      case 'internal':
        return 'Внутренний тариф';
      case 'starter':
        return 'Старт';
      case 'business':
        return 'Бизнес';
      case 'enterprise':
        return 'Корпоративный';
      default:
        final end = company.trialEndsAt;
        if (end == null) return 'Пробный период';
        return 'Пробный период до ${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}';
    }
  }

  Widget companyCard(CompanyDashboard dashboard) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceElevated,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppAdaptivePalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apartment_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dashboard.company.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppAdaptivePalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      planTitle(dashboard.company),
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => openPlans(dashboard),
                icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: const Text('Тарифы'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value:
                      '${dashboard.members.length} / ${dashboard.company.seatLimit}',
                  label: 'пользователей',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Metric(
                  value:
                      '${dashboard.objects.length} / ${dashboard.company.objectLimit}',
                  label: 'объектов',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget memberTile(CompanyDashboard dashboard, CompanyMember member) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final editable = !member.isOwner && member.userId != currentUserId;
    final subtitle = <String>[
      member.roleTitle,
      if (member.profession.isNotEmpty) member.profession,
      if (member.objectName.isNotEmpty) member.objectName,
      if (!member.isActive) 'Доступ отключён',
    ].join(' • ');

    return Card(
      elevation: 0,
      color: AppAdaptivePalette.surfaceElevated,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppAdaptivePalette.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: AppAdaptivePalette.surfaceSoft,
          foregroundColor: AppAdaptivePalette.textPrimary,
          child: Text(
            (member.fullName.isNotEmpty ? member.fullName : member.email)
                .characters
                .first
                .toUpperCase(),
          ),
        ),
        title: Text(
          member.fullName.isEmpty ? member.email : member.fullName,
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          member.email == member.fullName
              ? subtitle
              : '${member.email}\n$subtitle',
        ),
        isThreeLine: member.email != member.fullName,
        trailing: editable ? const Icon(Icons.chevron_right_rounded) : null,
        onTap: editable ? () => editMember(dashboard, member) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Компания и пользователи'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumBackdrop(
        child: FutureBuilder<CompanyDashboard>(
          future: dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return Center(
                child: PremiumDots(color: AppAdaptivePalette.textPrimary),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        'Не удалось загрузить компанию: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final dashboard = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                companyCard(dashboard),
                const SizedBox(height: 20),
                PremiumActionButton(
                  onPressed: () => openInvite(dashboard),
                  icon: Icons.person_add_alt_1_rounded,
                  label: 'Пригласить пользователя',
                ),
                if (dashboard.objects.isEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Чтобы пригласить прораба, сначала добавьте объект на вкладке «Главная».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppAdaptivePalette.textMuted),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Команда',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...dashboard.members.map(
                  (member) => memberTile(dashboard, member),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CompanyMemberEditorScreen extends StatefulWidget {
  final String companyId;
  final List<CompanyObject> objects;
  final CompanyMember? member;

  const CompanyMemberEditorScreen({
    super.key,
    required this.companyId,
    required this.objects,
    this.member,
  });

  @override
  State<CompanyMemberEditorScreen> createState() =>
      _CompanyMemberEditorScreenState();
}

class _CompanyMemberEditorScreenState extends State<CompanyMemberEditorScreen> {
  late final TextEditingController fullNameController;
  late final TextEditingController emailController;
  late final TextEditingController professionController;
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
    professionController = TextEditingController(
      text: widget.member?.profession ?? '',
    );
    const allowedRoles = <String>{
      'admin',
      'developer',
      'foreman',
      'lawyer',
      'accountant',
      'hr',
    };
    final currentRole = widget.member?.role;
    role = currentRole != null && allowedRoles.contains(currentRole)
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
    professionController.dispose();
    super.dispose();
  }

  Future<void> showInvitationLink(
    CompanyInviteResult result,
    String email,
  ) async {
    final description = result.requiresPasswordSetup
        ? 'Пользователь откроет ссылку, войдёт в нужную компанию и задаст пароль.'
        : 'Пользователь уже зарегистрирован. Ссылка выполнит безопасный вход и откроет нужную компанию.';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Ссылка приглашения готова'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$description\n\nПолучатель: $email',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppAdaptivePalette.border),
                  ),
                  child: SelectableText(
                    result.inviteUrl,
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Передайте эту ссылку только приглашённому человеку.',
                  style: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontWeight: FontWeight.w600,
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
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована')),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Копировать'),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeMember() async {
    if (!isEditing || isSaving) return;
    final member = widget.member!;
    final displayName = member.fullName.trim().isEmpty
        ? member.email
        : member.fullName.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          '$displayName потеряет доступ к этой компании и назначенному объекту. Его аккаунт и доступ к другим компаниям сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppAdaptivePalette.danger,
              foregroundColor: AppAdaptivePalette.onAccent,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
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

  Future<void> save() async {
    if (isSaving) return;
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final profession = professionController.text.trim();
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
          profession: profession,
          objectId: role == 'foreman' ? objectId : null,
        );
        if (mounted) Navigator.pop(context, 'Права пользователя обновлены');
      } else {
        final result = await CompanyRepository.inviteMember(
          companyId: widget.companyId,
          fullName: fullName,
          email: email,
          role: role,
          profession: profession,
          objectId: role == 'foreman' ? objectId : null,
        );
        if (!mounted) return;
        await showInvitationLink(result, email);
        if (!mounted) return;
        Navigator.pop(
          context,
          result.existingUser
              ? 'Ссылка входа создана, доступ к компании добавлен'
              : 'Ссылка приглашения создана',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          isEditing ? 'Права пользователя' : 'Пригласить пользователя',
        ),
      ),
      body: PremiumBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (!isEditing) ...[
              TextField(
                controller: fullNameController,
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Имя и фамилия',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                enabled: !isSaving,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: professionController,
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Профессия / должность',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(widget.member!.fullName),
                subtitle: Text(widget.member!.email),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: professionController,
                enabled: !isSaving,
                decoration: const InputDecoration(
                  labelText: 'Профессия / должность',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(
                labelText: 'Роль',
                prefixIcon: Icon(Icons.admin_panel_settings_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                DropdownMenuItem(
                  value: 'developer',
                  child: Text('Разработчик'),
                ),
                DropdownMenuItem(value: 'foreman', child: Text('Прораб')),
                DropdownMenuItem(value: 'lawyer', child: Text('Юрист')),
                DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
                DropdownMenuItem(value: 'hr', child: Text('HR-менеджер')),
              ],
              onChanged: isSaving
                  ? null
                  : (value) {
                      final nextRole = value ?? 'foreman';
                      setState(() {
                        role = nextRole;
                        if (role == 'foreman') {
                          final objectStillAvailable = widget.objects.any(
                            (item) => item.id == objectId,
                          );
                          if (!objectStillAvailable) {
                            objectId = widget.objects.isEmpty
                                ? null
                                : widget.objects.first.id;
                          }
                        } else {
                          objectId = null;
                        }
                      });
                    },
            ),
            if (role == 'foreman') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: widget.objects.any((item) => item.id == objectId)
                    ? objectId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Объект',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: widget.objects
                    .map(
                      (object) => DropdownMenuItem(
                        value: object.id,
                        child: Text(object.name),
                      ),
                    )
                    .toList(),
                onChanged: isSaving
                    ? null
                    : (value) => setState(() => objectId = value),
              ),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 14),
              Text(
                errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppAdaptivePalette.danger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 22),
            PremiumActionButton(
              onPressed: isSaving ? null : save,
              icon: isEditing ? Icons.save_outlined : Icons.link_rounded,
              label: isEditing ? 'Сохранить права' : 'Создать ссылку',
              isLoading: isSaving,
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppAdaptivePalette.danger,
                  side: BorderSide(
                    color: AppAdaptivePalette.danger.withValues(alpha: 0.55),
                  ),
                  minimumSize: const Size.fromHeight(54),
                ),
                onPressed: isSaving ? null : removeMember,
                icon: const Icon(Icons.person_remove_outlined),
                label: const Text('Удалить из компании'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppAdaptivePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          Text(label, style: TextStyle(color: AppAdaptivePalette.textMuted)),
        ],
      ),
    );
  }
}
