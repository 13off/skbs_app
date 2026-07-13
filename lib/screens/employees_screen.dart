import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../data/employee_private_data_repository.dart';
import '../data/employee_private_summary_exporter.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../navigation/app_page_route.dart';
import '../widgets/premium_ui.dart';
import 'add_employee_screen.dart';
import 'employee_details_screen.dart';
import 'payments_screen.dart';

const _card = Colors.white;
const _soft = Color(0xFFF2F3F5);
const _line = Color(0xFFE6E8EB);
const _text = Color(0xFF1F2328);
const _accent = Color(0xFF8F9499);

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
  final searchController = TextEditingController();
  final scrollController = ScrollController();

  List<Employee> employees = const [];
  bool loading = true;
  String? error;
  int requestId = 0;

  String? get objectName {
    final value = widget.selectedObjectName?.trim();
    return value == null || value.isEmpty ? null : value;
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
    scrollController.dispose();
    super.dispose();
  }

  Future<void> loadEmployees({bool showLoading = false}) async {
    final id = ++requestId;
    if (showLoading && employees.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final loaded = await EmployeeRepository.fetchEmployees(
        objectName: widget.selectedObjectName,
        includeFired: true,
      );
      if (!mounted || id != requestId) return;
      setState(() {
        employees = loaded;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted || id != requestId) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> openEmployee(Employee employee) async {
    final savedOffset = scrollController.hasClients
        ? scrollController.offset
        : 0.0;

    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeDetailsScreen(
          profile: widget.profile,
          employee: employee,
        ),
      ),
    );
    if (!mounted) return;

    await loadEmployees();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      final position = scrollController.position;
      final target = savedOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((position.pixels - target).abs() > .5) {
        scrollController.jumpTo(target);
      }
    });
  }

  Future<void> addEmployee() async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute(
        builder: (_) => AddEmployeeScreen(initialObjectName: objectName),
      ),
    );
    if (mounted && saved == true) await loadEmployees();
  }

  void openPayments() {
    Navigator.push(
      context,
      AppPageRoute(builder: (_) => const PaymentsScreen()),
    );
  }

  Future<void> downloadSummary() async {
    try {
      final source = employees.isNotEmpty
          ? List<Employee>.from(employees)
          : await EmployeeRepository.fetchEmployees(
              objectName: widget.selectedObjectName,
              includeFired: true,
            );
      final ids = source
          .map((employee) => employee.id ?? '')
          .where((id) => id.trim().isNotEmpty)
          .toList();
      final privateData =
          await EmployeePrivateDataRepository.fetchMapByEmployeeIds(ids);
      await EmployeePrivateSummaryExporter.downloadSummary(
        employees: source,
        privateDataByEmployeeId: privateData,
        objectName: widget.selectedObjectName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сводка скачана')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка формирования сводки: $e')),
        );
      }
    }
  }

  String money(int value) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$formatted ₽';
  }

  String duplicateKey(Employee employee) {
    final name = employee.name.trim().toLowerCase();
    final phone = employee.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return phone.isNotEmpty
        ? '$name::$phone'
        : '$name::${employee.position.trim().toLowerCase()}';
  }

  List<Employee> visibleEmployees() {
    final query = searchController.text.trim().toLowerCase();
    var source = query.isEmpty
        ? List<Employee>.from(employees)
        : employees.where((employee) {
            return employee.name.toLowerCase().contains(query) ||
                employee.position.toLowerCase().contains(query) ||
                employee.phone.toLowerCase().contains(query) ||
                employee.objectName.toLowerCase().contains(query);
          }).toList();

    if (objectName != null) return source;

    final groups = <String, List<Employee>>{};
    for (final employee in source) {
      groups.putIfAbsent(duplicateKey(employee), () => []).add(employee);
    }

    source = groups.values.map((group) {
      group.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.objectName.compareTo(b.objectName);
      });
      final main = group.first;
      final objects = group
          .map((employee) => employee.objectName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return Employee(
        main.name,
        main.position,
        main.status,
        id: main.id,
        phone: main.phone,
        objectName: objects.isEmpty ? main.objectName : objects.join(', '),
        dailyRate: main.dailyRate,
        isActive: group.any((employee) => employee.isActive),
        comment: main.comment,
      );
    }).toList();

    source.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return source;
  }

  Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final foreground = primary ? Colors.white : _accent;
    final background = primary ? _accent : _soft;

    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary ? _accent : _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    final scopeTitle = objectName ?? 'Все объекты';
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        actionButton(
          icon: Icons.payments_outlined,
          label: 'Выплаты',
          onTap: openPayments,
        ),
        actionButton(
          icon: Icons.table_view_outlined,
          label: 'Сводка',
          onTap: downloadSummary,
        ),
        actionButton(
          icon: Icons.person_add_alt_1,
          label: 'Добавить',
          onTap: addEmployee,
          primary: true,
        ),
      ],
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Сотрудники',
          style: TextStyle(
            color: _text,
            fontSize: 31,
            height: 1.05,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_outlined, size: 16, color: _accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                scopeTitle,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7075),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return PremiumWorkCard(
      radius: 28,
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, const SizedBox(height: 16), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 18),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }

  Widget search() {
    return TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО, должности, телефону...',
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
          borderSide: const BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }

  Widget employeeCard(Employee employee) {
    final fired = !employee.isActive;
    final subtitle = [
      employee.position,
      employee.phone,
      employee.objectName,
      'Ставка: ${money(employee.dailyRate)}',
    ].where((value) => value.trim().isNotEmpty).join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => openEmployee(employee),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: fired
                ? const Color(0xFFE9EAEB)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: fired ? const Color(0xFFD7D8DA) : _line,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: fired ? const Color(0xFFD9DADC) : _soft,
              foregroundColor: _text,
              child: Text(
                employee.name.trim().isEmpty
                    ? '?'
                    : employee.name.trim().characters.first,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    employee.name,
                    style: TextStyle(
                      color: fired ? const Color(0xFF686C70) : _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (fired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDADBDD),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      'Уволен',
                      style: TextStyle(
                        color: Color(0xFF565A5E),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(subtitle),
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ),
    );
  }

  Widget section(String title, List<Employee> items, {bool fired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fired) Divider(height: 30, color: Colors.grey.shade300),
        Padding(
          padding: EdgeInsets.only(top: fired ? 22 : 0, bottom: 10),
          child: Row(
            children: [
              Icon(
                fired ? Icons.archive_outlined : Icons.groups_outlined,
                size: 20,
                color: fired ? Colors.grey.shade700 : _text,
              ),
              const SizedBox(width: 8),
              Text(
                '$title: ${items.length}',
                style: TextStyle(
                  color: fired ? Colors.grey.shade700 : _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Активных сотрудников нет',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          ...items.map(employeeCard),
      ],
    );
  }

  List<Widget> content() {
    final visible = visibleEmployees();
    final active = visible.where((employee) => employee.isActive).toList();
    final fired = visible.where((employee) => !employee.isActive).toList();
    final result = <Widget>[
      header(),
      const SizedBox(height: 14),
      search(),
      const SizedBox(height: 16),
    ];

    if (loading && employees.isEmpty) {
      result.addAll([
        const SizedBox(height: 60),
        const Center(child: CircularProgressIndicator()),
      ]);
    } else if (error != null && employees.isEmpty) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            'Ошибка загрузки сотрудников: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    } else if (employees.isEmpty) {
      result.add(
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('Сотрудников пока нет', textAlign: TextAlign.center),
        ),
      );
    } else if (visible.isEmpty) {
      result.add(
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('Сотрудники не найдены', textAlign: TextAlign.center),
        ),
      );
    } else {
      result.add(section('Активные', active));
      if (fired.isNotEmpty) {
        result.add(section('Уволенные', fired, fired: true));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PremiumWorkBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                key: PageStorageKey(
                  'employees-${widget.selectedObjectName ?? 'all'}',
                ),
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: content(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
