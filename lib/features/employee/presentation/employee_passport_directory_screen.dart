import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/employee_repository.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import 'employee_professional_passport_viewer_screen.dart';
import '../../../navigation/app_page_route.dart';

class EmployeePassportDirectoryScreen extends StatefulWidget {
  const EmployeePassportDirectoryScreen({super.key});

  @override
  State<EmployeePassportDirectoryScreen> createState() =>
      _EmployeePassportDirectoryScreenState();
}

class _EmployeePassportDirectoryScreenState
    extends State<EmployeePassportDirectoryScreen> {
  late Future<List<Employee>> employeesFuture;
  final TextEditingController searchController = TextEditingController();
  String query = '';

  @override
  void initState() {
    super.initState();
    employeesFuture = loadEmployees();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<List<Employee>> loadEmployees() async {
    final rows = await EmployeeRepository.fetchEmployees(
      includeFired: true,
      forceRefresh: true,
    );
    return _deduplicatePeople(rows);
  }

  Future<void> refresh() async {
    final next = loadEmployees();
    setState(() => employeesFuture = next);
    await next;
  }

  Future<void> openEmployee(Employee employee) async {
    if ((employee.id ?? '').trim().isEmpty ||
        (employee.personId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('У сотрудника ещё не сформирована единая карточка'),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) =>
            EmployeeProfessionalPassportViewerScreen(employee: employee),
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
            return _DirectoryError(
              message: snapshot.error.toString().replaceFirst(
                'Exception: ',
                '',
              ),
              onRetry: refresh,
            );
          }

          final employees = snapshot.data ?? const <Employee>[];
          final cleanQuery = query.trim().toLowerCase();
          final visible = employees
              .where((employee) {
                if (cleanQuery.isEmpty) return true;
                final haystack = <String>[
                  employee.name,
                  employee.positionTitle,
                  employee.objectName,
                  employee.phone,
                ].join(' ').toLowerCase();
                return haystack.contains(cleanQuery);
              })
              .toList(growable: false);

          return AppPage(
            title: 'Паспорта специалистов',
            subtitle: 'Только реальные сотрудники и рабочие данные компании',
            showBackButton: true,
            onRefresh: refresh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PremiumWorkCard(
                  child: TextField(
                    controller: searchController,
                    onChanged: (value) => setState(() => query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Найти сотрудника',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Очистить поиск',
                              onPressed: () {
                                searchController.clear();
                                setState(() => query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Найдено: ${visible.length}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'Всего: ${employees.length}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  const PremiumWorkCard(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Сотрудники не найдены',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                else
                  ...visible.map(
                    (employee) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EmployeePassportTile(
                        employee: employee,
                        onTap: () => openEmployee(employee),
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

class _EmployeePassportTile extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;

  const _EmployeePassportTile({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final linked = (employee.personId ?? '').trim().isNotEmpty;
    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            _initials(employee.name),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employee.positionTitle.trim().isEmpty
                    ? 'Профессия не указана'
                    : employee.positionTitle,
              ),
              const SizedBox(height: 3),
              Text(
                linked
                    ? '${employee.objectName} · ${employee.isActive ? 'работает' : 'неактивен'}'
                    : 'Единая карточка ещё не сформирована',
                style: TextStyle(
                  color: linked
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        trailing: Icon(
          linked ? Icons.chevron_right_rounded : Icons.link_off_rounded,
        ),
      ),
    );
  }
}

class _DirectoryError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _DirectoryError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Паспорта специалистов',
      subtitle: 'Не удалось получить сотрудников компании',
      showBackButton: true,
      child: PremiumWorkCard(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
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

List<Employee> _deduplicatePeople(List<Employee> rows) {
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

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  return parts.map((part) => part.characters.first.toUpperCase()).join();
}
