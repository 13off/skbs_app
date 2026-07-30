import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_team_repository.dart';
import 'employee_team_screen.dart';

class EmployeeTeamTabScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeTeamTabScreen({
    super.key,
    required this.profile,
  });

  @override
  State<EmployeeTeamTabScreen> createState() => _EmployeeTeamTabScreenState();
}

class _EmployeeTeamTabScreenState extends State<EmployeeTeamTabScreen> {
  late Future<EmployeeTeamData> teamFuture;
  final searchController = TextEditingController();
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
        oldWidget.profile.objectName != widget.profile.objectName) {
      teamFuture = _load();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<EmployeeTeamData> _load() async {
    String? employeeId;
    if (widget.profile.isRolePreview) {
      final employees = await EmployeeRepository.fetchEmployees(
        includeFired: false,
        forceRefresh: true,
      );
      final seed = _resolvePreviewSeed(employees, widget.profile.objectName);
      if (seed == null) {
        throw Exception('Нет активного сотрудника с назначенным объектом');
      }
      employeeId = seed.id;
    }
    return EmployeeTeamRepository.fetch(employeeId: employeeId);
  }

  Employee? _resolvePreviewSeed(
    List<Employee> employees,
    String preferredObjectName,
  ) {
    final candidates = employees.where((employee) {
      return employee.isActive &&
          (employee.id ?? '').trim().isNotEmpty &&
          employee.objectName.trim().isNotEmpty;
    }).toList()
      ..sort((left, right) => left.name.compareTo(right.name));
    if (candidates.isEmpty) return null;

    final preferred = preferredObjectName.trim().toLowerCase();
    if (preferred.isNotEmpty) {
      for (final employee in candidates) {
        if (employee.objectName.trim().toLowerCase() == preferred) {
          return employee;
        }
      }
    }
    return candidates.first;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => teamFuture = next);
    await next;
  }

  Future<void> _openMember(
    EmployeeTeamMember member,
    String objectName,
  ) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeTeamMemberScreen(
          member: member,
          objectName: objectName,
        ),
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
        final members = data.members.where((member) {
          if (cleanQuery.isEmpty) return true;
          return <String>[
            member.fullName,
            member.profession,
            member.phone,
          ].join(' ').toLowerCase().contains(cleanQuery);
        }).toList(growable: false);
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                ...members.map(
                  (member) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumWorkCard(
                      padding: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.fromLTRB(14, 9, 10, 9),
                        onTap: () => _openMember(member, objectName),
                        leading: _EmployeeAvatar(member: member, size: 50),
                        title: Text(
                          member.fullName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (member.profession.isNotEmpty)
                                Text(member.profession),
                              const SizedBox(height: 4),
                              Text(
                                member.phone.isEmpty
                                    ? 'Телефон не указан'
                                    : member.phone,
                              ),
                              const SizedBox(height: 6),
                              _VerificationBadge(
                                verified: member.profileVerified,
                              ),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
                ),
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
      return _InitialsAvatar(name: member.fullName, size: size);
    }
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            _InitialsAvatar(name: member.fullName, size: size),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _InitialsAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
      ),
      child: Text(
        initials.isEmpty ? 'С' : initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.33,
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
    final scheme = Theme.of(context).colorScheme;
    final color = verified ? scheme.primary : scheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.help_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            verified ? 'Профиль подтверждён' : 'Профиль не подтверждён',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
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
    final scheme = Theme.of(context).colorScheme;
    return PremiumWorkCard(
      child: Column(
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

String _peopleWord(int value) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'коллег';
  if (mod10 == 1) return 'коллега';
  if (mod10 >= 2 && mod10 <= 4) return 'коллеги';
  return 'коллег';
}

String _errorText(Object? error) {
  return error
          ?.toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('FunctionsHttpError: ', '')
          .trim() ??
      'Не удалось загрузить команду объекта';
}
