import 'package:flutter/material.dart';

import '../data/employee_private_data_repository.dart';
import '../data/employee_private_summary_exporter.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import 'add_employee_screen.dart';
import 'employee_details_screen.dart';
import 'payments_screen.dart';

const Color _bg = Color(0xFFF7F8FA);
const Color _card = Color(0xFFFFFFFF);
const Color _softCard = Color(0xFFF2F3F5);
const Color _line = Color(0xFFE6E8EB);
const Color _text = Color(0xFF1F2328);
const Color _muted = Color(0xFF6B7075);
const Color _accentDark = Color(0xFF8F9499);
const Color _dangerSoft = Color(0xFFF1F2F4);

class EmployeesScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const EmployeesScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final TextEditingController searchController = TextEditingController();

  List<Employee> employees = [];
  bool isLoadingEmployees = true;
  String? loadErrorText;
  int loadGeneration = 0;

  String? get concreteObjectName {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) return null;

    return objectName;
  }

  @override
  void initState() {
    super.initState();

    loadEmployees(showLoading: true);
  }

  @override
  void didUpdateWidget(covariant EmployeesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      loadEmployees(showLoading: true);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadEmployees({bool showLoading = false}) async {
    final currentGeneration = ++loadGeneration;

    if (showLoading || employees.isEmpty) {
      setState(() {
        isLoadingEmployees = true;
        loadErrorText = null;
      });
    }

    try {
      final loadedEmployees = await EmployeeRepository.fetchEmployees(
        objectName: widget.selectedObjectName,
        includeFired: true,
      );

      if (!mounted || currentGeneration != loadGeneration) return;

      setState(() {
        employees = loadedEmployees;
        isLoadingEmployees = false;
        loadErrorText = null;
      });
    } catch (e) {
      if (!mounted || currentGeneration != loadGeneration) return;

      setState(() {
        isLoadingEmployees = false;
        loadErrorText = e.toString();
      });
    }
  }

  Future<void> openAddEmployee(BuildContext context) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddEmployeeScreen(initialObjectName: concreteObjectName),
      ),
    );

    if (!mounted || saved != true) return;

    await loadEmployees();
  }

  Future<void> openEmployeeDetails(
    BuildContext context,
    Employee employee,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmployeeDetailsScreen(profile: widget.profile, employee: employee),
      ),
    );

    if (!mounted) return;

    await loadEmployees();
  }

  void openPayments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentsScreen()),
    );
  }

  Future<void> downloadPrivateSummary() async {
    try {
      final employeesForSummary = employees.isNotEmpty
          ? List<Employee>.from(employees)
          : await EmployeeRepository.fetchEmployees(
              objectName: widget.selectedObjectName,
              includeFired: true,
            );

      final employeeIds = employeesForSummary
          .map((employee) => employee.id ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList();

      final privateData =
          await EmployeePrivateDataRepository.fetchMapByEmployeeIds(
            employeeIds,
          );

      await EmployeePrivateSummaryExporter.downloadSummary(
        employees: employeesForSummary,
        privateDataByEmployeeId: privateData,
        objectName: widget.selectedObjectName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Сводка скачана')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка формирования сводки: $e')));
    }
  }

  String firstLetter(String text) {
    final cleanText = text.trim();

    if (cleanText.isEmpty) return '?';

    return cleanText.characters.first;
  }

  String formatMoney(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$text ₽';
  }

  List<Employee> filterEmployees(List<Employee> sourceEmployees) {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) return sourceEmployees;

    return sourceEmployees.where((employee) {
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          employee.phone.toLowerCase().contains(query) ||
          employee.objectName.toLowerCase().contains(query);
    }).toList();
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.030),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;

          final title = const Text(
            'Сотрудники',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _text,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderActionButton(
                icon: Icons.payments_outlined,
                label: 'Выплаты',
                onTap: () {
                  openPayments(context);
                },
              ),
              _HeaderActionButton(
                icon: Icons.table_view_outlined,
                label: 'Сводка',
                onTap: downloadPrivateSummary,
              ),
              _HeaderActionButton(
                icon: Icons.person_add_alt_1,
                label: 'Добавить',
                primary: true,
                onTap: () {
                  openAddEmployee(context);
                },
              ),
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 16), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 18),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО, должности, телефону...',
        hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: _card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: _accentDark, width: 1.4),
        ),
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget buildEmployeeCard(BuildContext context, Employee employee) {
    final isFired = !employee.isActive;

    return Container(
      decoration: BoxDecoration(
        color: isFired ? _dangerSoft : _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isFired ? const Color(0xFFD3CAC0) : _line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: isFired ? const Color(0xFFD6CEC4) : _softCard,
          foregroundColor: _text,
          child: Text(
            firstLetter(employee.name),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                employee.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isFired ? Colors.grey.shade700 : _text,
                ),
              ),
            ),
            if (isFired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D0C7),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Уволен',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _text,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (employee.position.isNotEmpty)
                Text(
                  employee.position,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (employee.phone.isNotEmpty)
                Text(
                  employee.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (employee.objectName.isNotEmpty)
                Text(
                  employee.objectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              Text('Ставка: ${formatMoney(employee.dailyRate)}'),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          openEmployeeDetails(context, employee);
        },
      ),
    );
  }

  Widget buildSectionTitle({
    required String title,
    required int count,
    bool isFired = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isFired ? 22 : 0, bottom: 10),
      child: Row(
        children: [
          Icon(
            isFired ? Icons.archive_outlined : Icons.groups_outlined,
            size: 20,
            color: isFired ? Colors.grey.shade700 : _text,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: $count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isFired ? Colors.grey.shade700 : _text,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> buildEmployeesWidgets({
    required List<Employee> activeEmployees,
    required List<Employee> firedEmployees,
    required int totalEmployees,
  }) {
    if (activeEmployees.isEmpty && firedEmployees.isEmpty) {
      return [
        const SizedBox(height: 40),
        const Center(
          child: Text(
            'Сотрудники не найдены',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ),
      ];
    }

    return [
      buildSectionTitle(title: 'Активные', count: activeEmployees.length),
      if (activeEmployees.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            'Активных сотрудников нет',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        )
      else
        ...activeEmployees.map(
          (employee) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: buildEmployeeCard(context, employee),
          ),
        ),
      if (firedEmployees.isNotEmpty) ...[
        Divider(height: 30, color: Colors.grey.shade300),
        buildSectionTitle(
          title: 'Уволенные',
          count: firedEmployees.length,
          isFired: true,
        ),
        ...firedEmployees.map(
          (employee) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: buildEmployeeCard(context, employee),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visibleEmployees = filterEmployees(employees);

    final activeEmployees = visibleEmployees.where((employee) {
      return employee.isActive;
    }).toList();

    final firedEmployees = visibleEmployees.where((employee) {
      return !employee.isActive;
    }).toList();

    final content = <Widget>[
      buildHeader(),
      const SizedBox(height: 14),
      buildSearchField(),
      const SizedBox(height: 16),
    ];

    if (isLoadingEmployees && employees.isEmpty) {
      content.addAll([
        const SizedBox(height: 60),
        const Center(child: CircularProgressIndicator()),
      ]);
    } else if (loadErrorText != null && employees.isEmpty) {
      content.addAll([
        const SizedBox(height: 40),
        Center(
          child: Text(
            'Ошибка загрузки сотрудников: $loadErrorText',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ]);
    } else if (employees.isEmpty) {
      content.addAll([
        const SizedBox(height: 40),
        const Center(child: Text('Сотрудников пока нет')),
      ]);
    } else {
      content.addAll(
        buildEmployeesWidgets(
          activeEmployees: activeEmployees,
          firedEmployees: firedEmployees,
          totalEmployees: employees.length,
        ),
      );
    }

    return Container(
      color: _bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: content,
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : _accentDark;
    final background = primary ? _accentDark : _softCard;
    final border = primary ? _accentDark : _line;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
