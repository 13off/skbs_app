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
  final TextEditingController searchController = TextEditingController();
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
    return _deduplicateEmployees(rows)
        .where(
          (employee) =>
              (employee.id ?? '').trim().isNotEmpty &&
              (employee.personId ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
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

          final employees = snapshot.data ?? const <Employee>[];
          final cleanQuery = query.trim().toLowerCase();
          final visible = employees.where((employee) {
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
                PremiumWorkCard(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'ФИО, профессия или объект',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
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
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const _EmptyCard(
                    icon: Icons.person_search_rounded,
                    title: 'Сотрудники не найдены',
                    text: 'Измените запрос или обновите список.',
                  )
                else
                  ...visible.map(
                    (employee) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumWorkCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 10, 12, 10),
                          onTap: () => _open(employee),
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              _initials(employee.name),
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
  final TextEditingController searchController = TextEditingController();
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

  Future<void> _changeVisibility(EmployeeTeamData data) async {
    if (!data.canManageVisibility || savingVisibility) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _VisibilitySheet(
        currentScope: data.visibilityScope,
      ),
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

  Future<void> _openMember(EmployeeTeamMember member) async {
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeTeamMemberScreen(member: member),
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

          final subtitle = data.currentObject.isEmpty
              ? 'Текущий объект не указан'
              : 'Объект: ${data.currentObject}';
          return AppPage(
            title: 'Команда объекта',
            subtitle: widget.seedEmployeeName.trim().isEmpty
                ? subtitle
                : '${widget.seedEmployeeName.trim()} · $subtitle',
            showBackButton: true,
            onRefresh: _refresh,
            headerTrailing: data.canManageVisibility
                ? IconButton(
                    tooltip: 'Видимость профиля',
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
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          size: 31,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
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
                              const SizedBox(height: 5),
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
                PremiumWorkCard(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Найти коллегу или навык',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
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
                        ? 'Здесь появятся активные сотрудники с той же рабочей карточкой объекта.'
                        : 'Попробуйте изменить запрос.',
                  )
                else
                  ...members.map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TeamMemberTile(
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

class _TeamMemberTile extends StatelessWidget {
  final EmployeeTeamMember member;
  final VoidCallback onTap;

  const _TeamMemberTile({required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (member.profession.isNotEmpty) member.profession,
      if (member.extendedVisible && member.grade.isNotEmpty) member.grade,
    ].join(' · ');
    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 11, 12, 11),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            _initials(member.fullName),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          member.fullName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle.isEmpty ? 'Профессия не указана' : subtitle),
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

class EmployeeTeamMemberScreen extends StatelessWidget {
  final EmployeeTeamMember member;

  const EmployeeTeamMemberScreen({super.key, required this.member});

  Future<void> _copy(BuildContext context) async {
    final lines = <String>[
      member.fullName,
      if (member.profession.isNotEmpty) member.profession,
      if (member.grade.isNotEmpty) member.grade,
      if (member.experienceYears > 0)
        'Опыт: ${_formatDecimal(member.experienceYears)} лет',
      'Подтверждено: ${_formatDecimal(member.totalShifts)} смен, ${member.completedTasks} задач',
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
                  CircleAvatar(
                    radius: 38,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      _initials(member.fullName),
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
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
                  child: _TeamStatCard(
                    icon: Icons.calendar_month_rounded,
                    value: _formatDecimal(member.totalShifts),
                    label: 'смен подтверждено',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TeamStatCard(
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
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, bottom + 18),
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
              'Базовые сведения о работе видны коллегам объекта. Здесь настраивается только опыт, навыки и описание.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 14),
            ...employeeTeamVisibilityTitles.entries.map(
              (entry) => RadioListTile<String>(
                value: entry.key,
                groupValue: currentScope,
                onChanged: (value) => Navigator.of(context).pop(value),
                title: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  employeeTeamVisibilityDescriptions[entry.key] ?? '',
                ),
                secondary: Icon(_visibilityIcon(entry.key)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TeamStatCard({
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

List<Employee> _deduplicateEmployees(List<Employee> rows) {
  final byPerson = <String, Employee>{};
  for (final employee in rows) {
    final key = (employee.personId ?? '').trim().isNotEmpty
        ? 'person:${employee.personId}'
        : 'employee:${employee.id ?? employee.name}';
    final current = byPerson[key];
    if (current == null || (!current.isActive && employee.isActive)) {
      byPerson[key] = employee;
    }
  }
  final result = byPerson.values.toList();
  result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return result;
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
  return error
          ?.toString()
          .replaceFirst('Exception: ', '')
          .trim()
          .isNotEmpty ==
      true
      ? error!.toString().replaceFirst('Exception: ', '').trim()
      : 'Не удалось загрузить команду объекта';
}

IconData _visibilityIcon(String scope) {
  return switch (scope) {
    'private' => Icons.lock_outline_rounded,
    'company' => Icons.apartment_rounded,
    'employers' => Icons.public_rounded,
    _ => Icons.groups_rounded,
  };
}
