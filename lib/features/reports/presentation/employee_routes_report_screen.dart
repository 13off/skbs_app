import 'package:flutter/material.dart';

import '../../../data/employee_repository.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../../employee/data/employee_shift_action_repository.dart';
import '../../employee/presentation/employee_route_map_screen.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeRoutesReportScreen extends StatefulWidget {
  final String? selectedObjectName;

  const EmployeeRoutesReportScreen({super.key, this.selectedObjectName});

  @override
  State<EmployeeRoutesReportScreen> createState() =>
      _EmployeeRoutesReportScreenState();
}

class _EmployeeRoutesReportScreenState
    extends State<EmployeeRoutesReportScreen> {
  late Future<List<Employee>> future;
  Future<EmployeeRouteDay>? routeFuture;
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
          routeFuture = loadSelectedRoute();
          return employees;
        }
      }
    }
    selectedEmployee = employees.isEmpty ? null : employees.first;
    routeFuture = loadSelectedRoute();
    return employees;
  }

  Future<EmployeeRouteDay> loadSelectedRoute() async {
    final employeeId = selectedEmployee?.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      return EmployeeRouteDay(
        employeeId: '',
        workDate: selectedDate,
        shifts: const <EmployeeWorkShift>[],
        points: const <EmployeeLocationPoint>[],
      );
    }
    return EmployeeShiftActionRepository.fetchEmployeeRoute(
      employeeId: employeeId,
      date: selectedDate,
    );
  }

  Future<void> refresh() async {
    final next = loadEmployees(forceRefresh: true);
    setState(() => future = next);
    await next;
    if (mounted) setState(() {});
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
    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
      routeFuture = loadSelectedRoute();
    });
  }

  Future<void> openRoute() async {
    final employee = selectedEmployee;
    if (employee == null) return;
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => EmployeeRouteMapScreen(
          employee: employee,
          initialDate: selectedDate,
        ),
      ),
    );
  }

  Widget trackingSummary() {
    final future = routeFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<EmployeeRouteDay>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const PremiumWorkCard(
            child: SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }
        if (snapshot.hasError) {
          return PremiumWorkCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Не удалось проверить разрывы маршрута: '
                    '${_error(snapshot.error)}',
                  ),
                ),
              ],
            ),
          );
        }

        final route = snapshot.data;
        if (route == null || route.shifts.isEmpty) {
          return const PremiumWorkCard(
            child: Text('В выбранную дату рабочий день не начинался.'),
          );
        }

        final gaps = route.allGaps;
        final scheme = Theme.of(context).colorScheme;
        final lastPointAt = route.points.isEmpty
            ? route.shifts
                  .map((shift) => shift.lastPointAt)
                  .whereType<DateTime>()
                  .fold<DateTime?>(
                    null,
                    (latest, value) => latest == null || value.isAfter(latest)
                        ? value
                        : latest,
                  )
            : (List<EmployeeLocationPoint>.from(route.points)..sort(
                    (left, right) =>
                        left.recordedAt.compareTo(right.recordedAt),
                  ))
                  .last
                  .recordedAt;

        return PremiumWorkCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    gaps.isEmpty
                        ? Icons.check_circle_outline_rounded
                        : Icons.warning_amber_rounded,
                    color: gaps.isEmpty ? scheme.primary : scheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      gaps.isEmpty
                          ? 'Разрывов геолокации не обнаружено'
                          : 'Обнаружено разрывов: ${gaps.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Получено точек: ${route.points.length}'
                '${lastPointAt == null ? '' : ' · последняя ${_time(lastPointAt)}'}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (gaps.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(color: scheme.outlineVariant),
                const SizedBox(height: 4),
                ...gaps
                    .take(8)
                    .map(
                      (gap) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: _GapRow(gap: gap),
                      ),
                    ),
                if (gaps.length > 8) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Ещё разрывов: ${gaps.length - 8}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
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
              child: Text(
                'Для выбранного объекта активные сотрудники не найдены.',
              ),
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
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
                          .where(
                            (employee) =>
                                employee.id?.trim().isNotEmpty == true,
                          )
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
                            setState(() {
                              selectedEmployee = employee;
                              routeFuture = loadSelectedRoute();
                            });
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
              trackingSummary(),
              const SizedBox(height: 14),
              const PremiumWorkCard(
                child: Text(
                  'На карте отображаются координаты, которые приложение реально '
                  'получило во время рабочего дня. Разрывы показывают периоды, '
                  'когда координаты не поступали из-за закрытия приложения, '
                  'отключённой геолокации, отсутствия разрешения или системного '
                  'ограничения фоновой работы.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  final EmployeeTrackingGap gap;

  const _GapRow({required this.gap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            gap.inferred
                ? Icons.timeline_outlined
                : Icons.phonelink_erase_outlined,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _gapTitle(gap.reason),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${_time(gap.startedAt)}–${_time(gap.endedAt)} · '
                '${_duration(gap.duration)}',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (gap.details.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  gap.details.trim(),
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _gapTitle(String reason) {
  return switch (reason) {
    'application_interrupted' => 'Приложение или служба были прерваны',
    'location_service_disabled' => 'Геолокация была отключена',
    'permission_missing' => 'Нет постоянного разрешения',
    'stream_error' => 'Ошибка фоновой геолокации',
    'health_check_error' => 'Ошибка проверки геолокации',
    'tracking_interruption' => 'Фоновая запись была прервана',
    _ => 'Координаты не поступали',
  };
}

String _duration(Duration value) {
  final minutes = value.inMinutes;
  if (minutes < 60) return '$minutes мин';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '$hours ч' : '$hours ч $remainder мин';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
