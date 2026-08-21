import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_team_repository.dart';
import '../data/employee_work_action_repository.dart';
import 'employee_team_screen.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeTeamTabScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeTeamTabScreen({super.key, required this.profile});

  @override
  State<EmployeeTeamTabScreen> createState() => _EmployeeTeamTabScreenState();
}

class _EmployeeTeamTabScreenState extends State<EmployeeTeamTabScreen> {
  late Future<EmployeeTeamData> teamFuture;
  final TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    teamFuture = _load();
  }

  @override
  void didUpdateWidget(covariant EmployeeTeamTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.isRolePreview != widget.profile.isRolePreview ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      teamFuture = _load();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<EmployeeTeamData> _load() async {
    if (!widget.profile.isRolePreview) {
      return EmployeeTeamRepository.fetch();
    }

    final selection = await EmployeeWorkActionRepository.resolveSelection();
    return EmployeeTeamRepository.fetch(employeeId: selection.employeeId);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => teamFuture = next);
    await next;
  }

  Future<void> _openMember(EmployeeTeamMember member, String objectName) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) =>
            EmployeeTeamMemberScreen(member: member, objectName: objectName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTeamData>(
      future: teamFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Команда',
            subtitle: 'Коллеги текущего объекта',
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'Команда',
            subtitle: 'Не удалось загрузить коллег',
            onRefresh: _refresh,
            child: _TeamMessageCard(
              icon: Icons.cloud_off_rounded,
              title: 'Команда не загрузилась',
              text: _errorText(snapshot.error),
            ),
          );
        }

        final data = snapshot.data!;
        final cleanQuery = query.trim().toLowerCase();
        final members = data.members
            .where((member) {
              if (cleanQuery.isEmpty) return true;
              return <String>[
                member.fullName,
                member.profession,
                member.phone,
              ].join(' ').toLowerCase().contains(cleanQuery);
            })
            .toList(growable: false);
        final objectName = data.currentObject.trim();
        final subtitle = <String>[
          objectName.isEmpty ? 'Объект не указан' : objectName,
          '${data.members.length} ${_peopleWord(data.members.length)}',
        ].join(' · ');

        return AppPage(
          title: 'Команда',
          subtitle: subtitle,
          onRefresh: _refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    icon: const Icon(Icons.search_rounded),
                    hintText: 'Найти коллегу',
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: searchController,
                      builder: (_, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Очистить',
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (members.isEmpty)
                _TeamMessageCard(
                  icon: data.members.isEmpty
                      ? Icons.group_off_outlined
                      : Icons.person_search_rounded,
                  title: data.members.isEmpty
                      ? 'Коллег на объекте пока нет'
                      : 'Никого не нашли',
                  text: data.members.isEmpty
                      ? 'Здесь показываются только активные сотрудники этого же объекта.'
                      : 'Попробуйте изменить запрос.',
                )
              else
                for (var index = 0; index < members.length; index++) ...[
                  PremiumWorkCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                      onTap: () => _openMember(members[index], objectName),
                      leading: _EmployeeAvatar(
                        member: members[index],
                        size: 50,
                      ),
                      title: Text(
                        members[index].fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (members[index].profession.isNotEmpty)
                              Text(members[index].profession),
                            const SizedBox(height: 4),
                            Text(
                              members[index].phone.isEmpty
                                  ? 'Телефон не указан'
                                  : members[index].phone,
                            ),
                            const SizedBox(height: 6),
                            _VerificationBadge(
                              verified: members[index].profileVerified,
                            ),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  if (index != members.length - 1) const SizedBox(height: 10),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeAvatar extends StatelessWidget {
  final EmployeeTeamMember member;
  final double size;

  const _EmployeeAvatar({required this.member, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = member.avatarUrl.trim();
    if (url.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        child: Text(_initials(member.fullName)),
      );
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => CircleAvatar(
          radius: size / 2,
          child: Text(_initials(member.fullName)),
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool verified;

  const _VerificationBadge({required this.verified});

  @override
  Widget build(BuildContext context) {
    final color = verified
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.help_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          verified ? 'Профиль подтверждён' : 'Профиль не подтверждён',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TeamMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _TeamMessageCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _errorText(Object? error) {
  final text = error?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Попробуйте обновить страницу.' : text;
}

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final result = parts.map((part) => part.substring(0, 1).toUpperCase()).join();
  return result.isEmpty ? 'С' : result;
}

String _peopleWord(int value) {
  final lastTwo = value % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'коллег';
  return switch (value % 10) {
    1 => 'коллега',
    2 || 3 || 4 => 'коллеги',
    _ => 'коллег',
  };
}
