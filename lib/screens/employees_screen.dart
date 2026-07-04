import 'package:flutter/material.dart';

import '../data/employee_private_data_repository.dart';
import '../data/employee_private_summary_exporter.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import 'add_employee_screen.dart';
import 'employee_details_screen.dart';
import 'payments_screen.dart';

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

  String get objectTitle {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  String? get concreteObjectName {
    final objectName = widget.selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) return null;

    return objectName;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> openAddEmployee(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddEmployeeScreen(initialObjectName: concreteObjectName),
      ),
    );
  }

  void openEmployeeDetails(BuildContext context, Employee employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmployeeDetailsScreen(profile: widget.profile, employee: employee),
      ),
    );
  }

  void openPayments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaymentsScreen()),
    );
  }

  Future<void> downloadPrivateSummary() async {
    try {
      final employees = await EmployeeRepository.fetchEmployees(
        objectName: widget.selectedObjectName,
        includeFired: true,
      );
      final privateData = await EmployeePrivateDataRepository.fetchAllMap();

      await EmployeePrivateSummaryExporter.downloadSummary(
        employees: employees,
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

  List<Employee> filterEmployees(List<Employee> employees) {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) return employees;

    return employees.where((employee) {
      return employee.name.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query) ||
          employee.phone.toLowerCase().contains(query) ||
          employee.objectName.toLowerCase().contains(query);
    }).toList();
  }

  Widget buildSearchField() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО, должности, телефону или объекту',
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onChanged: (_) {
        setState(() {});
      },
    );
  }

  Widget buildEmployeeCard(BuildContext context, Employee employee) {
    final isFired = !employee.isActive;

    return Card(
      elevation: 0,
      color: isFired ? Colors.grey.shade200 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isFired
            ? BorderSide(color: Colors.grey.shade400)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: isFired ? Colors.grey.shade400 : null,
          child: Text(firstLetter(employee.name)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                employee.name,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isFired ? Colors.grey.shade700 : Colors.black87,
                ),
              ),
            ),
            if (isFired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Уволен',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (employee.position.isNotEmpty) Text(employee.position),
            if (employee.phone.isNotEmpty) Text(employee.phone),
            if (employee.objectName.isNotEmpty) Text(employee.objectName),
            Text('Ставка: ${formatMoney(employee.dailyRate)}'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          openEmployeeDetails(context, employee);
        },
      ),
    );
  }

  Widget buildCurrentObjectNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              concreteObjectName == null
                  ? 'Сейчас открыт список по всем объектам. При добавлении сотрудника объект можно выбрать вручную.'
                  : 'Сейчас открыт объект: $objectTitle. При добавлении сотрудника объект можно поменять.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle({
    required String title,
    required int count,
    bool isFired = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: isFired ? 24 : 0, bottom: 10),
      child: Row(
        children: [
          Icon(
            isFired ? Icons.archive_outlined : Icons.groups_outlined,
            size: 20,
            color: isFired ? Colors.grey.shade700 : Colors.black87,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: $count',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: isFired ? Colors.grey.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmployeesList({
    required List<Employee> activeEmployees,
    required List<Employee> firedEmployees,
    required int totalEmployees,
  }) {
    if (activeEmployees.isEmpty && firedEmployees.isEmpty) {
      return Center(
        child: Text(
          'Сотрудники не найдены',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Найдено: ${activeEmployees.length + firedEmployees.length} из $totalEmployees',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              buildSectionTitle(
                title: 'Активные',
                count: activeEmployees.length,
              ),
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
                Divider(height: 30, color: Colors.grey.shade400),
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
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Сотрудники',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () {
                    openPayments(context);
                  },
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Выплаты'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: downloadPrivateSummary,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('Сводка'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () {
                    openAddEmployee(context);
                  },
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Объект: $objectTitle'),
            const SizedBox(height: 14),

            buildCurrentObjectNotice(),

            const SizedBox(height: 14),

            buildSearchField(),

            const SizedBox(height: 14),

            Expanded(
              child: StreamBuilder<List<Employee>>(
                stream: EmployeeRepository.watchEmployees(
                  objectName: widget.selectedObjectName,
                  includeFired: true,
                ),
                builder: (context, snapshot) {
                  final employees = snapshot.data ?? [];
                  final visibleEmployees = filterEmployees(employees);

                  final activeEmployees = visibleEmployees.where((employee) {
                    return employee.isActive;
                  }).toList();

                  final firedEmployees = visibleEmployees.where((employee) {
                    return !employee.isActive;
                  }).toList();

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка загрузки сотрудников: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (employees.isEmpty) {
                    return const Center(child: Text('Сотрудников пока нет'));
                  }

                  return buildEmployeesList(
                    activeEmployees: activeEmployees,
                    firedEmployees: firedEmployees,
                    totalEmployees: employees.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
