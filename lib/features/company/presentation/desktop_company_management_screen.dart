import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/presentation/specialist_desktop_table.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/company_invitation_repository.dart';
import '../data/company_repository.dart';
import 'company_plans_screen.dart';
import 'desktop_company_user_dialogs.dart';

class DesktopCompanyManagementScreen extends StatefulWidget {
  final String companyId;

  const DesktopCompanyManagementScreen({
    super.key,
    required this.companyId,
  });

  @override
  State<DesktopCompanyManagementScreen> createState() =>
      _DesktopCompanyManagementScreenState();
}

class _DesktopCompanyManagementScreenState
    extends State<DesktopCompanyManagementScreen> {
  final searchController = TextEditingController();
  late Future<_DesktopCompanyData> future;

  String roleFilter = 'all';
  String accessFilter = 'all';
  String invitationStatusFilter = 'all';
  String? objectFilter;
  String? busyInvitationId;

  String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<_DesktopCompanyData> load() async {
    final values = await Future.wait<dynamic>([
      CompanyRepository.fetchDashboard(widget.companyId),
      CompanyInvitationRepository.fetchInvitations(widget.companyId),
    ]);
    return _DesktopCompanyData(
      dashboard: values[0] as CompanyDashboard,
      invitations: values[1] as List<CompanyInvitation>,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  void showMessage(String text) {
    if (!mounted || text.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openInvite(CompanyDashboard dashboard) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => DesktopCompanyMemberDialog(
        companyId: widget.companyId,
        objects: dashboard.objects,
      ),
    );
    if (result == null || !mounted) return;
    showMessage(result);
    await refresh();
  }

  Future<void> editMember(
    CompanyDashboard dashboard,
    CompanyMember member,
  ) async {
    if (member.isOwner || member.userId == currentUserId) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => DesktopCompanyMemberDialog(
        companyId: widget.companyId,
        objects: dashboard.objects,
        member: member,
      ),
    );
    if (result == null || !mounted) return;
    showMessage(result);
    await refresh();
  }

  void openPlans(CompanyDashboard dashboard) {
    Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => CompanyPlansScreen(dashboard: dashboard),
      ),
    );
  }

  Future<void> recreateInvitation(
    CompanyDashboard dashboard,
    CompanyInvitation invitation,
  ) async {
    if (busyInvitationId != null) return;
    if (invitation.role == 'foreman' &&
        !dashboard.objects.any((object) => object.id == invitation.objectId)) {
      showMessage('Назначенный объект больше недоступен. Создайте новое приглашение.');
      return;
    }

    setState(() => busyInvitationId = invitation.id);
    try {
      final result = await CompanyRepository.inviteMember(
        companyId: widget.companyId,
        fullName: invitation.fullName,
        email: invitation.email,
        role: invitation.role,
        objectId: invitation.role == 'foreman' ? invitation.objectId : null,
      );
      if (!mounted) return;
      await showDesktopInvitationLink(
        context,
        result: result,
        email: invitation.email,
      );
      if (mounted) await refresh();
    } catch (error) {
      showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busyInvitationId = null);
    }
  }

  Future<void> revokeInvitation(CompanyInvitation invitation) async {
    if (!invitation.isPending || busyInvitationId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить приглашение?'),
        content: Text(
          'Ссылка для ${invitation.email} перестанет считаться активной. При необходимости можно будет создать новую.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Назад'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: specialistDanger),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.link_off_rounded),
            label: const Text('Отменить приглашение'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => busyInvitationId = invitation.id);
    try {
      await CompanyInvitationRepository.revokeInvitation(
        companyId: widget.companyId,
        invitationId: invitation.id,
      );
      showMessage('Приглашение отменено');
      if (mounted) await refresh();
    } catch (error) {
      showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busyInvitationId = null);
    }
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
        return 'Пробный период до ${formatDate(end)}';
    }
  }

  String formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  String normalize(String value) => value.trim().toLowerCase();

  bool matchesSearch(String value) {
    final query = normalize(searchController.text);
    return query.isEmpty || normalize(value).contains(query);
  }

  List<CompanyMember> visibleMembers(CompanyDashboard dashboard) {
    final validObject = dashboard.objects.any((item) => item.id == objectFilter)
        ? objectFilter
        : null;
    final result = dashboard.members.where((member) {
      if (roleFilter != 'all' && member.role != roleFilter) return false;
      if (accessFilter == 'active' && !member.isActive) return false;
      if (accessFilter == 'inactive' && member.isActive) return false;
      if (validObject != null && member.objectId != validObject) return false;
      return matchesSearch(
        '${member.fullName} ${member.email} ${member.roleTitle} ${member.objectName}',
      );
    }).toList();
    result.sort((a, b) {
      int rank(CompanyMember member) {
        if (member.isOwner) return 0;
        if (member.role == 'admin') return 1;
        if (member.role == 'foreman') return 2;
        return 3;
      }

      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return result;
  }

  List<CompanyInvitation> visibleInvitations(
    List<CompanyInvitation> invitations,
  ) {
    return invitations.where((invitation) {
      if (invitationStatusFilter != 'all' &&
          invitation.effectiveStatus != invitationStatusFilter) {
        return false;
      }
      return matchesSearch(
        '${invitation.fullName} ${invitation.email} ${invitation.roleTitle} ${invitation.objectName} ${invitation.statusTitle}',
      );
    }).toList();
  }

  Color roleColor(String role) {
    switch (role) {
      case 'owner':
      case 'admin':
        return const Color(0xFF4C6076);
      case 'foreman':
        return const Color(0xFF6A7155);
      case 'lawyer':
        return const Color(0xFF735E78);
      case 'accountant':
        return const Color(0xFF48706A);
      default:
        return specialistMuted;
    }
  }

  Color invitationColor(CompanyInvitation invitation) {
    switch (invitation.effectiveStatus) {
      case 'accepted':
        return specialistSuccess;
      case 'revoked':
      case 'expired':
        return specialistDanger;
      default:
        return specialistWarning;
    }
  }

  Widget companyBanner(CompanyDashboard dashboard) {
    final company = dashboard.company;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF343A40), Color(0xFF62686E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${planTitle(company)} • ${dashboard.members.length} из ${company.seatLimit} мест • ${dashboard.objects.length} из ${company.objectLimit} объектов',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.76),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            ),
            onPressed: () => openPlans(dashboard),
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Тарифы и лимиты'),
          ),
        ],
      ),
    );
  }

  Widget metrics(_DesktopCompanyData data) {
    final members = data.dashboard.members;
    final active = members.where((item) => item.isActive).length;
    final admins = members
        .where((item) => item.role == 'owner' || item.role == 'admin')
        .length;
    final foremen = members.where((item) => item.role == 'foreman').length;
    final specialists = members
        .where((item) => item.role == 'lawyer' || item.role == 'accountant')
        .length;
    final pending = data.invitations.where((item) => item.isPending).length;

    return Row(
      children: [
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.groups_outlined,
            label: 'Активные пользователи',
            value: '$active',
            hint: 'Лимит: ${data.dashboard.company.seatLimit}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Руководители',
            value: '$admins',
            accent: roleColor('admin'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.engineering_outlined,
            label: 'Прорабы',
            value: '$foremen',
            accent: roleColor('foreman'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.badge_outlined,
            label: 'Юрист и бухгалтер',
            value: '$specialists',
            accent: roleColor('lawyer'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SpecialistMetricCard(
            icon: Icons.mark_email_unread_outlined,
            label: 'Ожидают входа',
            value: '$pending',
            accent: pending > 0 ? specialistWarning : specialistSuccess,
          ),
        ),
      ],
    );
  }

  Widget filters(CompanyDashboard dashboard) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'ФИО, email, роль или объект...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: roleFilter,
              decoration: const InputDecoration(labelText: 'Роль'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Все роли')),
                DropdownMenuItem(value: 'owner', child: Text('Владелец')),
                DropdownMenuItem(value: 'admin', child: Text('Администратор')),
                DropdownMenuItem(value: 'foreman', child: Text('Прораб')),
                DropdownMenuItem(value: 'lawyer', child: Text('Юрист')),
                DropdownMenuItem(value: 'accountant', child: Text('Бухгалтер')),
              ],
              onChanged: (value) => setState(() => roleFilter = value ?? 'all'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: dashboard.objects.any(
                (object) => object.id == objectFilter,
              )
                  ? objectFilter
                  : null,
              decoration: const InputDecoration(labelText: 'Объект'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все объекты'),
                ),
                ...dashboard.objects.map(
                  (object) => DropdownMenuItem<String>(
                    value: object.id,
                    child: Text(object.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => objectFilter = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: accessFilter,
              decoration: const InputDecoration(labelText: 'Доступ'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Любой доступ')),
                DropdownMenuItem(value: 'active', child: Text('Активен')),
                DropdownMenuItem(value: 'inactive', child: Text('Отключён')),
              ],
              onChanged: (value) =>
                  setState(() => accessFilter = value ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: specialistText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: specialistMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget memberTable(CompanyDashboard dashboard, List<CompanyMember> members) {
    return SpecialistDesktopTable(
      minWidth: 1200,
      columns: const [
        SpecialistTableColumn('Пользователь', flex: 4),
        SpecialistTableColumn('Роль', flex: 2),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Доступ', flex: 2),
        SpecialistTableColumn('Права', flex: 3),
        SpecialistTableColumn('', flex: 1, alignment: Alignment.centerRight),
      ],
      rows: members.map((member) {
        final editable = !member.isOwner && member.userId != currentUserId;
        final displayName = member.fullName.trim().isEmpty
            ? member.email
            : member.fullName.trim();
        return SpecialistTableRowData(
          onTap: editable ? () => editMember(dashboard, member) : null,
          cells: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: specialistSoft,
                  foregroundColor: specialistText,
                  child: Text(
                    displayName.characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      specialistCellText(displayName, weight: FontWeight.w900),
                      specialistCellText(
                        member.email,
                        color: specialistMuted,
                        weight: FontWeight.w600,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SpecialistStatusPill(
              label: member.roleTitle,
              color: roleColor(member.role),
            ),
            specialistCellText(
              member.objectName.isEmpty ? 'Все объекты компании' : member.objectName,
              color: specialistMuted,
            ),
            SpecialistStatusPill(
              label: member.isActive ? 'Активен' : 'Отключён',
              color: member.isActive ? specialistSuccess : specialistDanger,
              icon: member.isActive
                  ? Icons.verified_user_outlined
                  : Icons.block_outlined,
            ),
            specialistCellText(
              member.isOwner
                  ? 'Полный доступ владельца'
                  : member.role == 'admin'
                      ? 'Управление компанией и всеми объектами'
                      : member.role == 'foreman'
                          ? 'Работа только на назначенном объекте'
                          : 'Отдельная рабочая платформа специалиста',
              color: specialistMuted,
            ),
            editable
                ? const Icon(Icons.chevron_right_rounded, color: specialistMuted)
                : Icon(
                    member.isOwner ? Icons.lock_outline : Icons.person_outline,
                    color: specialistMuted,
                  ),
          ],
        );
      }).toList(),
    );
  }

  Widget buildInvitationStatusFilter() {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String>(
        initialValue: invitationStatusFilter,
        decoration: const InputDecoration(
          labelText: 'Статус приглашения',
          prefixIcon: Icon(Icons.filter_alt_outlined),
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('Все приглашения')),
          DropdownMenuItem(value: 'pending', child: Text('Ожидают входа')),
          DropdownMenuItem(value: 'accepted', child: Text('Приняты')),
          DropdownMenuItem(value: 'expired', child: Text('Истекли')),
          DropdownMenuItem(value: 'revoked', child: Text('Отменены')),
        ],
        onChanged: (value) =>
            setState(() => invitationStatusFilter = value ?? 'all'),
      ),
    );
  }

  Widget invitationTable(
    CompanyDashboard dashboard,
    List<CompanyInvitation> invitations,
  ) {
    return SpecialistDesktopTable(
      minWidth: 1250,
      columns: const [
        SpecialistTableColumn('Получатель', flex: 4),
        SpecialistTableColumn('Роль', flex: 2),
        SpecialistTableColumn('Объект', flex: 3),
        SpecialistTableColumn('Создано', flex: 2),
        SpecialistTableColumn('Срок / принято', flex: 2),
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('Действия', flex: 3, alignment: Alignment.centerRight),
      ],
      rows: invitations.map((invitation) {
        final busy = busyInvitationId == invitation.id;
        return SpecialistTableRowData(
          cells: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                specialistCellText(
                  invitation.fullName,
                  weight: FontWeight.w900,
                ),
                specialistCellText(
                  invitation.email,
                  color: specialistMuted,
                  weight: FontWeight.w600,
                  maxLines: 1,
                ),
              ],
            ),
            SpecialistStatusPill(
              label: invitation.roleTitle,
              color: roleColor(invitation.role),
            ),
            specialistCellText(
              invitation.objectName.isEmpty
                  ? 'Без привязки к объекту'
                  : invitation.objectName,
              color: specialistMuted,
            ),
            specialistCellText(formatDate(invitation.createdAt), maxLines: 1),
            specialistCellText(
              invitation.acceptedAt != null
                  ? 'Принято ${formatDate(invitation.acceptedAt!)}'
                  : 'До ${formatDate(invitation.expiresAt)}',
              color: specialistMuted,
              maxLines: 1,
            ),
            SpecialistStatusPill(
              label: invitation.statusTitle,
              color: invitationColor(invitation),
              icon: invitation.isPending
                  ? Icons.schedule_send_outlined
                  : invitation.effectiveStatus == 'accepted'
                      ? Icons.mark_email_read_outlined
                      : Icons.link_off_outlined,
            ),
            Wrap(
              spacing: 6,
              alignment: WrapAlignment.end,
              children: [
                Tooltip(
                  message: 'Создать и скопировать новую ссылку',
                  child: IconButton.filledTonal(
                    onPressed: busy
                        ? null
                        : () => recreateInvitation(dashboard, invitation),
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.content_copy_rounded),
                  ),
                ),
                if (invitation.isPending)
                  Tooltip(
                    message: 'Отменить приглашение',
                    child: IconButton(
                      color: specialistDanger,
                      onPressed: busy ? null : () => revokeInvitation(invitation),
                      icon: const Icon(Icons.link_off_rounded),
                    ),
                  ),
              ],
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget actions(CompanyDashboard dashboard) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        IconButton.filledTonal(
          tooltip: 'Обновить',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        OutlinedButton.icon(
          onPressed: () => openPlans(dashboard),
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const Text('Тарифы'),
        ),
        FilledButton.icon(
          onPressed: () => openInvite(dashboard),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Пригласить пользователя'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DesktopCompanyData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SpecialistDesktopPage(
            storageKey: 'desktop-company-users-loading',
            title: 'Компания и пользователи',
            subtitle: 'Загружаем команду, роли и приглашения',
            children: [
              SpecialistMessageCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Загружаем центр управления',
                loading: true,
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return SpecialistDesktopPage(
            storageKey: 'desktop-company-users-error',
            title: 'Компания и пользователи',
            subtitle: 'Команда, роли, объекты и приглашения',
            children: [
              SpecialistMessageCard(
                icon: Icons.cloud_off_outlined,
                title: 'Не удалось загрузить компанию',
                description: snapshot.error.toString(),
                actionLabel: 'Повторить',
                onAction: refresh,
              ),
            ],
          );
        }

        final data = snapshot.data!;
        final members = visibleMembers(data.dashboard);
        final invitations = visibleInvitations(data.invitations);
        return SpecialistDesktopPage(
          storageKey: 'desktop-company-users-${widget.companyId}',
          title: 'Компания и пользователи',
          subtitle:
              'Единый центр ролей, объектов, доступа и приглашений компании',
          trailing: actions(data.dashboard),
          onRefresh: refresh,
          children: [
            companyBanner(data.dashboard),
            const SizedBox(height: 18),
            metrics(data),
            const SizedBox(height: 18),
            filters(data.dashboard),
            const SizedBox(height: 22),
            sectionHeader(
              title: 'Команда',
              subtitle:
                  'Пользователи компании, их роли, назначенные объекты и доступ',
            ),
            if (members.isEmpty)
              const SpecialistMessageCard(
                icon: Icons.person_search_outlined,
                title: 'Пользователи не найдены',
                description: 'Измените поиск или выбранные фильтры.',
              )
            else
              memberTable(data.dashboard, members),
            const SizedBox(height: 24),
            sectionHeader(
              title: 'Приглашения',
              subtitle:
                  'Активные, принятые, истёкшие и отменённые ссылки доступа',
              trailing: buildInvitationStatusFilter(),
            ),
            if (invitations.isEmpty)
              const SpecialistMessageCard(
                icon: Icons.mark_email_unread_outlined,
                title: 'Приглашения не найдены',
                description: 'Измените поиск или фильтр по статусу.',
              )
            else
              invitationTable(data.dashboard, invitations),
          ],
        );
      },
    );
  }
}

class _DesktopCompanyData {
  final CompanyDashboard dashboard;
  final List<CompanyInvitation> invitations;

  const _DesktopCompanyData({
    required this.dashboard,
    required this.invitations,
  });
}
