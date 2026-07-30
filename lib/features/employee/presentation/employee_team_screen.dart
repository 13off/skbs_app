import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/employee_repository.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_team_repository.dart';

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
      CupertinoPageRoute<void>(
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
              title: 'Команды объектов',
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
          }).toList(growable: false);

          return AppPage(
            title: 'Команды объектов',
            subtitle: 'Выберите реального сотрудника для просмотра его команды',
            showBackButton: true,
            onRefresh: _refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SearchCard(
                  controller: searchController,
                  value: query,
                  hint: 'ФИО, профессия или объект',
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
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 10, 12, 10),
                          onTap: () => _open(employee),
                          leading: _Avatar(name: employee.name),
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
  bool savingVisibility = false;

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

  Future<void> _openMember(EmployeeTeamMember member) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeTeamMemberScreen(member: member),
      ),
    );
  }

  Future<void> _changeVisibility(EmployeeTeamData data) async {
    if (!data.canManageVisibility || savingVisibility) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => _VisibilitySheet(currentScope: data.visibilityScope),
    );
    if (selected == null || selected == data.visibilityScope || !mounted) return;

    setState(() => savingVisibility = true);
    try {
      final saved = await EmployeeTeamRepository.updateVisibility(selected);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        teamFuture = Future<EmployeeTeamData>.value(
          data.copyWith(visibilityScope: saved),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Видимость: ${employeeTeamVisibilityTitles[saved] ?? saved}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorText(error))),
      );
    } finally {
      if (mounted) setState(() => savingVisibility = false);
    }
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
              message: 'Собираем команду объекта',
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _TeamErrorPage(
              title: 'Команда объекта',
              message: _errorText(snapshot.error),
              onRetry: _refresh,
            );
          }

          final data = snapshot.data!;
          final cleanQuery = query.trim().toLowerCase();
          final members = data.members.where((member) {
            if (cleanQuery.isEmpty) return true;
            return <String>[
              member.fullName,
              member.profession,
              member.grade,
              ...member.skills,
            ].join(' ').toLowerCase().contains(cleanQuery);
          }).toList(growable: false);
          final objectText = data.currentObject.isEmpty
              ? 'Текущий объект не указан'
              : 'Объект: ${data.currentObject}';

          return AppPage(
            title: 'Команда объекта',
            subtitle: widget.seedEmployeeName.trim().isEmpty
                ? objectText
                : '${widget.seedEmployeeName.trim()} · $objectText',
            showBackButton: true,
            onRefresh: _refresh,
            headerTrailing: data.canManageVisibility
                ? IconButton(
                    tooltip: 'Кто видит мой профиль',
                    onPressed: savingVisibility
                        ? null
                        : () => _changeVisibility(data),
                    icon: savingVisibility
                        ? const SizedBox.square(
                            dimension: 21,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(Icons.visibility_outlined),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  child: Row(
                    children: [
                      _SquareIcon(icon: Icons.groups_rounded),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.currentObject.isEmpty
                                  ? 'Объект не определён'
                                  : data.currentObject,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${data.members.length} ${_peopleWord(data.members.length)} в команде',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if (data.canManageVisibility) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ваш профиль: ${employeeTeamVisibilityTitles[data.visibilityScope] ?? data.visibilityScope}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SearchCard(
                  controller: searchController,
                  value: query,
                  hint: 'Найти коллегу или навык',
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
                        ? 'Здесь появятся активные сотрудники того же объекта.'
                        : 'Попробуйте изменить запрос.',
                  )
                else
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MemberTile(
                        member: member,
                        onTap: () => _openMember(member),
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

  const EmployeeTeamMemberScreen({super.key, required this.member});

  Future<void> _copy(BuildContext context) async {
    final lines = <String>[
      member.fullName,
      if (member.profession.isNotEmpty) member.profession,
      if (member.grade.isNotEmpty) member.grade,
      'Подтверждено: ${_formatDecimal(member.totalShifts)} смен, ${member.completedTasks} задач',
      if (member.experienceYears > 0)
        'Опыт: ${_formatDecimal(member.experienceYears)} лет',
      if (member.skills.isNotEmpty) 'Навыки: ${member.skills.join(', ')}',
      if (member.about.isNotEmpty) member.about,
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль коллеги скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: AppPage(
        title: member.fullName,
        subtitle: member.objectName.isEmpty
            ? 'Профессиональный профиль коллеги'
            : 'Команда объекта: ${member.objectName}',
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumWorkCard(
              child: Column(
                children: [
                  _Avatar(name: member.fullName, radius: 38),
                  const SizedBox(height: 14),
                  Text(
                    member.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    <String>[
                      if (member.profession.isNotEmpty) member.profession,
                      if (member.extendedVisible && member.grade.isNotEmpty)
                        member.grade,
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_month_rounded,
                    value: _formatDecimal(member.totalShifts),
                    label: 'смен подтверждено',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    icon: Icons.task_alt_rounded,
                    value: '${member.completedTasks}',
                    label: 'задач выполнено',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (!member.extendedVisible)
              const _EmptyCard(
                icon: Icons.visibility_off_outlined,
                title: 'Расширенный профиль скрыт',
                text:
                    'Коллега оставил доступными только базовые рабочие сведения и подтверждённую статистику.',
              )
            else ...[
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Опыт и квалификация',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (member.about.isNotEmpty)
                      Text(
                        member.about,
                        style: const TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (member.about.isNotEmpty) const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (member.grade.isNotEmpty)
                          Chip(
                            avatar: const Icon(
                              Icons.military_tech_rounded,
                              size: 18,
                            ),
                            label: Text(member.grade),
                          ),
                        if (member.experienceYears > 0)
                          Chip(
                            avatar: const Icon(Icons.history_rounded, size: 18),
                            label: Text(
                              '${_formatDecimal(member.experienceYears)} лет опыта',
                            ),
                          ),
                        if (member.readyForRotation)
                          const Chip(
                            avatar: Icon(Icons.luggage_rounded, size: 18),
                            label: Text('Готов к вахте'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Навыки',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (member.skills.isEmpty)
                      Text(
                        'Коллега пока не указал навыки.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: member.skills
                            .map(
                              (skill) => Chip(
                                avatar:
                                    const Icon(Icons.check_rounded, size: 17),
                                label: Text(skill),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Скопировать безопасный профиль'),
              ),
            ],
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.firstWorkDate == null
                          ? 'Показатели собраны из рабочих данных AppСтрой.'
                          : 'Первая подтверждённая смена: ${DateFormat('d MMMM y', 'ru_RU').format(member.firstWorkDate!)}.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
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
}

class _VisibilitySheet extends StatelessWidget {
  final String currentScope;

  const _VisibilitySheet({required this.currentScope});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Кто видит мой профиль',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Базовые сведения видны коллегам объекта. Здесь настраиваются опыт, навыки и описание.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            ...employeeTeamVisibilityTitles.entries.map((entry) {
              final selected = entry.key == currentScope;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => Navigator.of(context).pop(entry.key),
                leading: Icon(_visibilityIcon(entry.key)),
                title: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  employeeTeamVisibilityDescriptions[entry.key] ?? '',
                ),
                trailing: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              );
            }),
          ],
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
    final role = <String>[
      if (member.profession.isNotEmpty) member.profession,
      if (member.extendedVisible && member.grade.isNotEmpty) member.grade,
    ].join(' · ');
    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        onTap: onTap,
        leading: _Avatar(name: member.fullName),
        title: Text(
          member.fullName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role.isEmpty ? 'Профессия не указана' : role),
              const SizedBox(height: 4),
              Text(
                '${_formatDecimal(member.totalShifts)} смен · ${member.completedTasks} задач',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (!member.extendedVisible) ...[
                const SizedBox(height: 4),
                Text(
                  'Расширенный профиль скрыт',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  final TextEditingController controller;
  final String value;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchCard({
    required this.controller,
    required this.value,
    required this.hint,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Очистить',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;

  const _Avatar({required this.name, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: radius >= 30 ? 21 : 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SquareIcon extends StatelessWidget {
  final IconData icon;

  const _SquareIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        icon,
        size: 31,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
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
          Icon(icon, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
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
      subtitle: 'Не удалось получить рабочие данные',
      showBackButton: true,
      child: PremiumWorkCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            PremiumActionButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  return parts.map((part) => part.characters.first.toUpperCase()).join();
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _peopleWord(int count) {
  final mod100 = count % 100;
  final mod10 = count % 10;
  if (mod100 >= 11 && mod100 <= 14) return 'человек';
  if (mod10 == 1) return 'человек';
  if (mod10 >= 2 && mod10 <= 4) return 'человека';
  return 'человек';
}

String _errorText(Object? error) {
  final text = error?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось загрузить команду объекта' : text;
}

IconData _visibilityIcon(String scope) {
  return switch (scope) {
    'private' => Icons.lock_outline_rounded,
    'company' => Icons.apartment_rounded,
    'employers' => Icons.public_rounded,
    _ => Icons.groups_rounded,
  };
}
