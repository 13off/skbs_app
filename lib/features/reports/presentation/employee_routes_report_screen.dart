import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../employee/presentation/employee_route_map_screen.dart';

class EmployeeRoutesReportScreen extends StatefulWidget {
  final String? selectedObjectName;

  const EmployeeRoutesReportScreen({
    super.key,
    this.selectedObjectName,
  });

  @override
  State<EmployeeRoutesReportScreen> createState() =>
      _EmployeeRoutesReportScreenState();
}

class _EmployeeRoutesReportScreenState
    extends State<EmployeeRoutesReportScreen> {
  late Future<List<Employee>> future;
  Employee? selectedEmployee;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    future = loadEmployees();
  }

  Future<List<Employee>> loadEmployees({bool forceRefresh = false}) async {
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: widget.selectedObjectName,
      includeFired: false,
      forceRefresh: forceRefresh,
    );
    if (selectedEmployee != null) {
      for (final employee in employees) {
        if (employee.id == selectedEmployee?.id) {
          selectedEmployee = employee;
          return employees;
        }
      }
    }
    selectedEmployee = employees.isEmpty ? null : employees.first;
    return employees;
  }

  Future<void> refresh() async {
    final next = loadEmployees(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 31)),
      helpText: 'Дата маршрута',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked == null) return;
    setState(() => selectedDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> openRoute() async {
    final employee = selectedEmployee;
    if (employee == null) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeRouteMapScreen(
          employee: employee,
          initialDate: selectedDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Маршруты сотрудников',
      subtitle: widget.selectedObjectName?.trim().isNotEmpty == true
          ? 'Объект: ${widget.selectedObjectName!.trim()}'
          : 'Все объекты',
      onRefresh: refresh,
      child: FutureBuilder<List<Employee>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Не удалось загрузить сотрудников',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(_error(snapshot.error)),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final employees = snapshot.data ?? const <Employee>[];
          if (employees.isEmpty) {
            return const PremiumWorkCard(
              child: Text('Для выбранного объекта активные сотрудники не найдены.'),
            );
          }

          final selectedId = selectedEmployee?.id;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Сотрудник',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_search_outlined),
                        labelText: 'Выберите сотрудника',
                      ),
                      items: employees
                          .where((employee) => employee.id?.trim().isNotEmpty == true)
                          .map(
                            (employee) => DropdownMenuItem<String>(
                              value: employee.id,
                              child: Text(
                                employee.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        for (final employee in employees) {
                          if (employee.id == value) {
                            setState(() => selectedEmployee = employee);
                            break;
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(_date(selectedDate)),
                    ),
                    const SizedBox(height: 14),
                    PremiumActionButton(
                      label: 'Показать маршрут',
                      icon: Icons.route_outlined,
                      onPressed: selectedEmployee == null ? null : openRoute,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const PremiumWorkCard(
                child: Text(
                  'На карте отображаются координаты, которые приложение реально '
                  'получило во время рабочего дня. Точки соединяются по времени.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _error(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Неизвестная ошибка' : text;
}
