from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    source = read(path)
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{path}: expected one match, found {count}')
    write(path, source.replace(old, new, 1))


APP_PAGE = r'''import 'package:flutter/material.dart';

import 'premium_ui_v2.dart';

const Color _appText = Color(0xFF1F2328);
const Color _appMuted = Color(0xFF6B7075);

class AppPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: title,
                      subtitle: subtitle,
                      trailing: headerTrailing,
                    ),
                    const SizedBox(height: 18),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  Widget buildIdentity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumBrandMark(size: 50, animate: false),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ',
                style: TextStyle(
                  color: _appMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.75,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _appText,
                  fontSize: 30,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appMuted,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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
    return PremiumWorkCard(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final action = trailing;
          if (action == null) return buildIdentity();

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildIdentity(),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildIdentity()),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}
'''
write('lib/widgets/app_page.dart', APP_PAGE)

# Архив: нижняя панель должна занимать только собственную высоту.
archive_path = 'lib/features/archive/presentation/archive_management_screen_v3.dart'
archive_old = r'''      bottomNavigationBar: Container(
        color: const Color(0xFFF8F7F3),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: selectedCount == 0 || isBusy
                          ? null
                          : restoreSelected,
                      icon: const Icon(Icons.restore_rounded),
                      label: const Text('Восстановить'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF9D3E38),
                      ),
                      onPressed: selectedCount == 0 || isBusy
                          ? null
                          : deleteSelectedForever,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Удалить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),'''
archive_new = r'''      bottomNavigationBar: Material(
        color: const Color(0xFFF8F7F3),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: selectedCount == 0 || isBusy
                            ? null
                            : restoreSelected,
                        icon: const Icon(Icons.restore_rounded),
                        label: const Text('Восстановить'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9D3E38),
                        ),
                        onPressed: selectedCount == 0 || isBusy
                            ? null
                            : deleteSelectedForever,
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),'''
replace_once(archive_path, archive_old, archive_new)

# Выплаты: сначала объект, затем сотрудник выбранного объекта.
payment_path = 'lib/screens/add_payment_screen.dart'
replace_once(
    payment_path,
    "import '../data/employee_repository.dart';\n",
    "import '../data/employee_repository.dart';\nimport '../data/object_repository.dart';\n",
)
replace_once(
    payment_path,
    "  String? selectedEmployeeId;\n  DateTime paymentDate = DateTime.now();\n",
    "  String? selectedObjectName;\n  String? selectedEmployeeId;\n  DateTime paymentDate = DateTime.now();\n",
)
replace_once(
    payment_path,
    "  List<Employee> employees = [];\n  List<PickedPaymentReceiptFile> receiptFiles = [];\n",
    "  List<String> objectNames = [];\n  List<Employee> employees = [];\n  List<PickedPaymentReceiptFile> receiptFiles = [];\n",
)

payment_source = read(payment_path)
load_start = payment_source.index('  Future<void> loadEmployees() async {')
load_end = payment_source.index('  Employee? findSelectedEmployee()', load_start)
new_load = r'''  Future<void> loadEmployees() async {
    setState(() {
      isLoadingEmployees = true;
      errorText = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(includeFired: true),
        ObjectRepository.fetchObjectNames(),
      ]);
      final loadedEmployees = results[0] as List<Employee>;
      final employeesWithId = loadedEmployees
          .where((employee) => employee.id != null)
          .toList();
      final names = <String>{
        ...(results[1] as List<String>).map((name) => name.trim()),
        ...employeesWithId.map((employee) => employee.objectName.trim()),
      }.where((name) => name.isNotEmpty).toList()
        ..sort();

      Employee? selectedEmployee;
      for (final employee in employeesWithId) {
        if (employee.id == selectedEmployeeId) {
          selectedEmployee = employee;
          break;
        }
      }

      if (!mounted) return;

      setState(() {
        employees = employeesWithId;
        objectNames = names;

        if (selectedEmployee != null) {
          final employeeObject = selectedEmployee.objectName.trim();
          selectedObjectName = employeeObject.isEmpty ? null : employeeObject;
        } else {
          final objectStillExists = selectedObjectName != null &&
              names.contains(selectedObjectName!.trim());
          if (!objectStillExists) {
            selectedObjectName = null;
            selectedEmployeeId = null;
          } else if (!employeesForSelectedObject().any(
            (employee) => employee.id == selectedEmployeeId,
          )) {
            selectedEmployeeId = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки объектов и сотрудников: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingEmployees = false;
        });
      }
    }
  }

  List<Employee> employeesForSelectedObject() {
    final objectName = selectedObjectName?.trim();
    if (objectName == null || objectName.isEmpty) return const <Employee>[];

    final result = employees
        .where((employee) => employee.objectName.trim() == objectName)
        .toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

'''
write(payment_path, payment_source[:load_start] + new_load + payment_source[load_end:])

replace_once(
    payment_path,
    r'''    if (selectedEmployee == null || selectedEmployee.id == null) {
      setState(() {
        errorText = 'Выберите сотрудника';
      });
      return;
    }
''',
    r'''    if (selectedObjectName == null || selectedObjectName!.trim().isEmpty) {
      setState(() {
        errorText = 'Сначала выберите объект';
      });
      return;
    }

    if (selectedEmployee == null || selectedEmployee.id == null) {
      setState(() {
        errorText = 'Выберите сотрудника';
      });
      return;
    }
''',
)

replace_once(
    payment_path,
    r'''    } else {
      body = ListView(
''',
    r'''    } else {
      final availableEmployees = employeesForSelectedObject();
      final employeeFieldValue = availableEmployees.any(
        (employee) => employee.id == selectedEmployeeId,
      )
          ? selectedEmployeeId
          : null;

      body = ListView(
''',
)

payment_source = read(payment_path)
field_start = payment_source.index(
    '          DropdownButtonFormField<String>(\n            initialValue: selectedEmployeeId,'
)
field_end = payment_source.index(
    '\n\n          const SizedBox(height: 14),', field_start
)
new_fields = r'''          DropdownButtonFormField<String>(
            key: const ValueKey('payment-object-field'),
            initialValue: selectedObjectName,
            items: objectNames.map((objectName) {
              return DropdownMenuItem<String>(
                value: objectName,
                child: Text(objectName),
              );
            }).toList(),
            onChanged: isSaving
                ? null
                : (objectName) {
                    setState(() {
                      selectedObjectName = objectName;
                      selectedEmployeeId = null;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Объект',
              hintText: 'Сначала выберите объект',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            key: ValueKey('payment-employee-${selectedObjectName ?? 'none'}'),
            initialValue: employeeFieldValue,
            items: availableEmployees.map((employee) {
              return DropdownMenuItem<String>(
                value: employee.id,
                child: Text(employee.name),
              );
            }).toList(),
            onChanged: isSaving || selectedObjectName == null
                ? null
                : (employeeId) {
                    setState(() {
                      selectedEmployeeId = employeeId;
                    });
                  },
            decoration: InputDecoration(
              labelText: 'Сотрудник',
              hintText: selectedObjectName == null
                  ? 'Сначала выберите объект'
                  : availableEmployees.isEmpty
                      ? 'На объекте нет сотрудников'
                      : 'Выберите сотрудника',
              border: const OutlineInputBorder(),
            ),
          ),'''
write(payment_path, payment_source[:field_start] + new_fields + payment_source[field_end:])

# Главная: единая объёмная шапка как в «Задачах» и «Профиле».
home_path = 'lib/screens/home_screen.dart'
replace_once(
    home_path,
    "import '../widgets/notification_bell.dart';\n",
    "import '../widgets/app_page.dart';\nimport '../widgets/notification_bell.dart';\n",
)
home_source = read(home_path)
header_start = home_source.index('  Widget buildHeader(BuildContext context, DateTime today) {')
header_end = home_source.index('  Widget buildDashboard({', header_start)
new_home_header = r'''  Widget buildHeader(BuildContext context, DateTime today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Главная',
          subtitle: 'Рабочая сводка по объектам, людям, задачам и выплатам',
          trailing: NotificationBell(
            selectedObjectName: widget.selectedObjectName,
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          radius: 26,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    color: _muted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Сегодня, ${dateText(today)}',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              buildObjectSelector(context),
            ],
          ),
        ),
      ],
    );
  }

'''
write(home_path, home_source[:header_start] + new_home_header + home_source[header_end:])

# Сотрудники: та же шапка и объёмная панель действий.
employees_path = 'lib/screens/employees_screen.dart'
replace_once(
    employees_path,
    "import '../widgets/premium_ui.dart';\n",
    "import '../widgets/app_page.dart';\nimport '../widgets/premium_ui.dart';\n",
)
employees_source = read(employees_path)
employees_header_start = employees_source.index('  Widget header() {')
employees_header_end = employees_source.index('  Widget search() {', employees_header_start)
new_employees_header = r'''  Widget header() {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Сотрудники',
          subtitle: 'Люди, ставки и документы • $scopeTitle',
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(14),
          child: actions,
        ),
      ],
    );
  }

'''
write(
    employees_path,
    employees_source[:employees_header_start] +
        new_employees_header +
        employees_source[employees_header_end:],
)

# Табель: единая шапка и та же анимация даты, что в «Задачах».
timesheet_path = 'lib/screens/timesheet_screen.dart'
replace_once(
    timesheet_path,
    "import '../widgets/premium_ui.dart';\n",
    "import '../widgets/app_page.dart';\nimport '../widgets/premium_ui.dart';\n",
)
replace_once(
    timesheet_path,
    r'''  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
''',
    r'''  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String get objectTitle =>
      cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';
''',
)

timesheet_source = read(timesheet_path)
date_start = timesheet_source.index('  Widget buildDatePanel() {')
date_end = timesheet_source.index('  Widget buildWorkedSummaryPanel({', date_start)
new_timesheet_header_and_date = r'''  Widget buildPageHeader() {
    return AppPageHeader(
      title: 'Табель',
      subtitle: 'Смены сотрудников за выбранную дату • $objectTitle',
      trailing: widget.profile.isAdmin
          ? FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => _TimesheetReportRoute(
                      selectedObjectName: widget.selectedObjectName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('Отчет'),
            )
          : null,
    );
  }

  Widget buildDateArrow({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E2DC)),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }

  Widget buildDatePanel() {
    final dateActionsEnabled = !isSaving && !isAttendanceLoading;

    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          buildDateArrow(
            icon: Icons.chevron_left_rounded,
            onTap: dateActionsEnabled
                ? () {
                    changeDate(selectedDate.subtract(const Duration(days: 1)));
                  }
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: PremiumPressable(
              onTap: dateActionsEnabled ? pickDate : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4E2DC)),
                ),
                child: Column(
                  children: [
                    Text(
                      shortDate(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weekDayName(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          buildDateArrow(
            icon: Icons.chevron_right_rounded,
            onTap: dateActionsEnabled
                ? () {
                    changeDate(selectedDate.add(const Duration(days: 1)));
                  }
                : null,
          ),
        ],
      ),
    );
  }

'''
write(
    timesheet_path,
    timesheet_source[:date_start] +
        new_timesheet_header_and_date +
        timesheet_source[date_end:],
)

replace_once(
    timesheet_path,
    r'''    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Табель'),
        actions: [
          if (widget.profile.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => _TimesheetReportRoute(
                        selectedObjectName: widget.selectedObjectName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('Отчет'),
              ),
            ),
        ],
      ),
      body: PremiumWorkBackdrop(
''',
    r'''    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PremiumWorkBackdrop(
''',
)
replace_once(
    timesheet_path,
    r'''                        children: [
                          buildDatePanel(),
''',
    r'''                        children: [
                          buildPageHeader(),
                          const SizedBox(height: 14),
                          buildDatePanel(),
''',
)

# Обновляем функциональный контракт под единую шапку табеля.
contract_path = 'test/functional_contract_test.dart'
replace_once(
    contract_path,
    '        "title: const Text(\'Табель\')",\n',
    '        "title: \'Табель\'",\n',
)

CONTRACT = r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('archive bottom actions never hide archived items', () {
    final archive = source(
      'lib/features/archive/presentation/archive_management_screen_v3.dart',
    );

    expect(archive, contains('buildTopPanel()'));
    expect(archive, contains('buildContent()'));
    expect(archive, contains('heightFactor: 1'));
    expect(archive, contains('height: 54'));
    expect(archive, isNot(contains('child: Center(\n            child: ConstrainedBox')));
  });

  test('payment flow selects object before employee', () {
    final payment = source('lib/screens/add_payment_screen.dart');
    final objectField = payment.indexOf("labelText: 'Объект'");
    final employeeField = payment.indexOf("labelText: 'Сотрудник'");

    expect(objectField, greaterThan(-1));
    expect(employeeField, greaterThan(objectField));
    expect(payment, contains('employeesForSelectedObject()'));
    expect(payment, contains("errorText = 'Сначала выберите объект'"));
    expect(payment, contains("selectedEmployeeId = null"));
  });

  test('main employee and timesheet pages share task profile header', () {
    final appPage = source('lib/widgets/app_page.dart');
    expect(appPage, contains('class AppPageHeader'));
    expect(appPage, contains('APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ'));

    for (final path in <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/employees_screen.dart',
      'lib/screens/timesheet_screen.dart',
      'lib/screens/tasks_screen.dart',
      'lib/screens/profile_screen.dart',
    ]) {
      final screen = source(path);
      expect(
        screen,
        anyOf(contains('AppPageHeader('), contains('return AppPage(')),
        reason: '$path должен использовать единую объёмную шапку',
      );
    }
  });

  test('timesheet date uses the same premium press motion as tasks', () {
    final timesheet = source('lib/screens/timesheet_screen.dart');
    expect(timesheet, contains('Widget buildDateArrow'));
    expect(timesheet, contains('PremiumPressable('));
    expect(timesheet, contains('borderRadius: BorderRadius.circular(20)'));
  });
}
'''
write('test/archive_payment_page_contract_test.dart', CONTRACT)
