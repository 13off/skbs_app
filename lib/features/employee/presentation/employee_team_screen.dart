import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/employee_repository.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_team_repository.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeTeamSeedDirectoryScreen extends StatefulWidget {
  const EmployeeTeamSeedDirectoryScreen({super.key});

  @override
  State<EmployeeTeamSeedDirectoryScreen> createState() =>
      _EmployeeTeamSeedDirectoryScreenState();
}

class _EmployeeTeamSeedDirectoryScreenState
    extends State<EmployeeTeamSeedDirectoryScreen> {
  late Future<List<Employee>> employeesFuture;
  final searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    employeesFuture = _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<Employee>> _load() async {
    final rows = await EmployeeRepository.fetchEmployees(
      includeFired: false,
      forceRefresh: true,
    );
    final byPerson = <String, Employee>{};
    for (final employee in rows) {
      final personId = (employee.personId ?? '').trim();
      final employeeId = (employee.id ?? '').trim();
      if (personId.isEmpty || employeeId.isEmpty) continue;
      final current = byPerson[personId];
      if (current == null || (!current.isActive && employee.isActive)) {
        byPerson[personId] = employee;
      }
    }
    final result = byPerson.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => employeesFuture = next);
    await next;
  }

  Future<void> _open(Employee employee) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => EmployeeTeamScreen(
          employeeId: employee.id,
          seedEmployeeName: employee.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: FutureBuilder<List<Employee>>(
        future: employeesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumLoadingScreen(
              message: 'Загружаем сотрудников компании',
            );
          }
          if (snapshot.hasError) {
            return _TeamErrorPage(
              title: 'Команда',
              message: _errorText(snapshot.error),
              onRetry: _refresh,
            );
          }

          final cleanQuery = query.trim().toLowerCase();
          final employees = (snapshot.data ?? const <Employee>[])
              .where((employee) {
                if (cleanQuery.isEmpty) return true;
                return <String>[
                  employee.name,
                  employee.positionTitle,
                  employee.objectName,
                ].join(' ').toLowerCase().contains(cleanQuery);
              })
              .toList(growable: false);

          return AppPage(
            title: 'Команда',
            subtitle: 'Выберите сотрудника, чей объект нужно посмотреть',
            showBackButton: true,
            onRefresh: _refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchCard(
                  controller: searchController,
                  hint: 'ФИО, должность или объект',
                  onChanged: (value) => setState(() => query = value),
                  onClear: () {
                    searchController.clear();
                    setState(() => query = '');
                  },
                ),
                const SizedBox(height: 14),
                if (employees.isEmpty)
                  const _EmptyCard(
                    icon: Icons.person_search_rounded,
                    title: 'Сотрудники не найдены',
                    text: 'Измените запрос или обновите список.',
                  )
                else
                  ...employees.map(
                    (employee) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumWorkCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(
                            14,
                            8,
                            10,
                            8,
                          ),
                          onTap: () => _open(employee),
                          leading: _InitialsAvatar(
                            name: employee.name,
                            size: 48,
                          ),
                          title: Text(
                            employee.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            <String>[
                              if (employee.positionTitle.trim().isNotEmpty)
                                employee.positionTitle.trim(),
                              if (employee.objectName.trim().isNotEmpty)
                                employee.objectName.trim(),
                            ].join(' · '),
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
      ),
    );
  }
}

class EmployeeTeamScreen extends StatefulWidget {
  final String? employeeId;
  final String seedEmployeeName;

  const EmployeeTeamScreen({
    super.key,
    this.employeeId,
    this.seedEmployeeName = '',
  });

  @override
  State<EmployeeTeamScreen> createState() => _EmployeeTeamScreenState();
}

class _EmployeeTeamScreenState extends State<EmployeeTeamScreen> {
  late Future<EmployeeTeamData> teamFuture;
  final searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    teamFuture = _load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<EmployeeTeamData> _load() {
    return EmployeeTeamRepository.fetch(employeeId: widget.employeeId);
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
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: FutureBuilder<EmployeeTeamData>(
        future: teamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const PremiumLoadingScreen(
              message: 'Загружаем команду объекта',
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _TeamErrorPage(
              title: 'Команда',
              message: _errorText(snapshot.error),
              onRetry: _refresh,
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
            if (widget.seedEmployeeName.trim().isNotEmpty)
              widget.seedEmployeeName.trim(),
            objectName.isEmpty ? 'Объект не указан' : objectName,
            '${data.members.length} ${_peopleWord(data.members.length)}',
          ].join(' · ');

          return AppPage(
            title: 'Команда',
            subtitle: subtitle,
            showBackButton: true,
            onRefresh: _refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchCard(
                  controller: searchController,
                  hint: 'Найти коллегу',
                  onChanged: (value) => setState(() => query = value),
                  onClear: () {
                    searchController.clear();
                    setState(() => query = '');
                  },
                ),
                const SizedBox(height: 14),
                if (members.isEmpty)
                  _EmptyCard(
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
                      child: _MemberTile(
                        member: member,
                        onTap: () => _openMember(member, objectName),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EmployeeTeamMemberScreen extends StatelessWidget {
  final EmployeeTeamMember member;
  final String objectName;

  const EmployeeTeamMemberScreen({
    super.key,
    required this.member,
    required this.objectName,
  });

  Future<void> _copyPhone(BuildContext context) async {
    if (member.phone.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: member.phone));
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Номер телефона скопирован')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: AppPage(
        title: 'Профиль сотрудника',
        subtitle: objectName.isEmpty ? 'Коллега по объекту' : objectName,
        showBackButton: true,
        child: PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: _EmployeeAvatar(member: member, size: 92)),
              const SizedBox(height: 16),
              Text(
                member.fullName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (member.profession.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  member.profession,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Center(
                child: _VerificationBadge(verified: member.profileVerified),
              ),
              const SizedBox(height: 22),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 12),
              Text(
                'Телефон',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                member.phone.isEmpty ? 'Не указан' : member.phone,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: member.phone.isEmpty
                    ? null
                    : () => _copyPhone(context),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Скопировать номер'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final EmployeeTeamMember member;
  final VoidCallback onTap;

  const _MemberTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        onTap: onTap,
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
                Text(
                  member.profession,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text(
                member.phone.isEmpty ? 'Телефон не указан' : member.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _VerificationBadge(
                verified: member.profileVerified,
                compact: true,
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool verified;
  final bool compact;

  const _VerificationBadge({required this.verified, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = verified
        ? AppAdaptivePalette.success
        : scheme.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_rounded : Icons.help_outline_rounded,
            size: compact ? 15 : 18,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            verified ? 'Профиль подтверждён' : 'Профиль не подтверждён',
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchCard({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(Icons.search_rounded),
          hintText: hint,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Очистить',
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamErrorPage extends StatelessWidget {
  final String title;
  final String message;
  final Future<void> Function() onRetry;

  const _TeamErrorPage({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: title,
      subtitle: 'Не удалось загрузить данные',
      showBackButton: true,
      child: PremiumWorkCard(
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'С';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _peopleWord(int count) {
  final lastTwo = count % 100;
  if (lastTwo >= 11 && lastTwo <= 14) return 'сотрудников';
  return switch (count % 10) {
    1 => 'сотрудник',
    2 || 3 || 4 => 'сотрудника',
    _ => 'сотрудников',
  };
}

String _errorText(Object? error) {
  final text = error?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось загрузить команду объекта' : text;
}
