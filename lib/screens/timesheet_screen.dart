import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:intl/intl.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../app/app_theme.dart';
import '../widgets/premium_ui.dart';
import 'period_timesheet_screen.dart';

class TimesheetScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const TimesheetScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends State<TimesheetScreen> {
  DateTime selectedDate = AppState.today;

  Future<List<Employee>>? employeesFuture;

  Map<String, double> shiftValuesByEmployeeId = {};
  Map<String, double> originalShiftValuesByEmployeeId = {};

  bool isAttendanceLoading = false;
  bool isSaving = false;
  bool hasUnsavedChanges = false;
  String? errorText;

  final TextEditingController searchController = TextEditingController();

  final List<double> quickShiftOptions = const [0, 0.5, 1, 1.5, 2];

  List<double> get allShiftOptions {
    return List.generate(31, (index) {
      return index / 10;
    });
  }

  @override
  void initState() {
    super.initState();
    reloadEmployees();
    loadAttendance();
  }

  @override
  void didUpdateWidget(covariant TimesheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      reloadEmployees();
      loadAttendance();
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void reloadEmployees() {
    employeesFuture = EmployeeRepository.fetchEmployees(
      objectName: widget.selectedObjectName,
    );
  }

  String formatShift(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String shortDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String weekDayName(DateTime date) {
    const names = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье',
    ];

    return names[date.weekday - 1];
  }

  double shiftValueFor(Employee employee) {
    final employeeId = employee.id;

    if (employeeId == null) return 0.0;

    return shiftValuesByEmployeeId[employeeId] ?? 0.0;
  }

  void setShiftValue(Employee employee, double value) {
    final employeeId = employee.id;

    if (employeeId == null) return;

    final currentValue = shiftValuesByEmployeeId[employeeId] ?? 0.0;

    if (currentValue == value) return;

    setState(() {
      shiftValuesByEmployeeId[employeeId] = value;
      hasUnsavedChanges = true;
    });
  }

  double totalShiftsFor(List<Employee> employees) {
    return employees.fold<double>(0, (sum, employee) {
      return sum + shiftValueFor(employee);
    });
  }

  int workedCountFor(List<Employee> employees) {
    return employees.where((employee) => shiftValueFor(employee) > 0).length;
  }

  List<Employee> filterEmployees(List<Employee> employees) {
    final searchText = searchController.text.trim().toLowerCase();

    return employees.where((employee) {
      final searchMatches =
          searchText.isEmpty ||
          employee.name.toLowerCase().contains(searchText) ||
          employee.position.toLowerCase().contains(searchText);

      return searchMatches;
    }).toList();
  }

  Future<void> loadAttendance() async {
    setState(() {
      isAttendanceLoading = true;
      errorText = null;
    });

    try {
      final values = await AttendanceRepository.fetchShiftValuesForDate(
        selectedDate,
        objectName: widget.selectedObjectName,
      );

      if (!mounted) return;

      setState(() {
        shiftValuesByEmployeeId = Map<String, double>.from(values);
        originalShiftValuesByEmployeeId = Map<String, double>.from(values);
        hasUnsavedChanges = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка загрузки табеля: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isAttendanceLoading = false;
        });
      }
    }
  }

  Future<void> changeDate(DateTime newDate) async {
    setState(() {
      selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      shiftValuesByEmployeeId = {};
      originalShiftValuesByEmployeeId = {};
      hasUnsavedChanges = false;
    });

    await loadAttendance();
  }

  Future<void> pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      helpText: 'Выберите дату табеля',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );

    if (pickedDate == null) return;

    await changeDate(pickedDate);
  }

  void setVisibleEmployeesShifts({
    required List<Employee> employees,
    required double value,
  }) {
    var changed = false;

    final nextValues = Map<String, double>.from(shiftValuesByEmployeeId);

    for (final employee in employees) {
      final employeeId = employee.id;

      if (employeeId == null) continue;

      final currentValue = nextValues[employeeId] ?? 0.0;

      if (currentValue == value) continue;

      nextValues[employeeId] = value;
      changed = true;
    }

    if (!changed) return;

    setState(() {
      shiftValuesByEmployeeId = nextValues;
      hasUnsavedChanges = true;
    });
  }

  Future<void> showShiftPicker(Employee employee) async {
    final employeeId = employee.id;

    if (employeeId == null) return;

    final currentValue = shiftValuesByEmployeeId[employeeId] ?? 0.0;

    double selectedValue = currentValue;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employee.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Смена: ${formatShift(selectedValue)}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 220,
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 48,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(
                          initialItem: !allShiftOptions.contains(currentValue)
                              ? 0
                              : allShiftOptions.indexOf(currentValue),
                        ),
                        onSelectedItemChanged: (index) {
                          setModalState(() {
                            selectedValue = allShiftOptions[index];
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: allShiftOptions.length,
                          builder: (context, index) {
                            final value = allShiftOptions[index];

                            return Center(
                              child: Text(
                                formatShift(value),
                                style: TextStyle(
                                  fontSize: value == selectedValue ? 26 : 18,
                                  fontWeight: value == selectedValue
                                      ? FontWeight.w900
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          setShiftValue(employee, selectedValue);
                          Navigator.pop(context);
                        },
                        child: const Text('Выбрать'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> saveTimesheet(List<Employee> allEmployees) async {
    setState(() {
      isSaving = true;
      errorText = null;
    });

    try {
      await AttendanceRepository.saveTimesheet(
        date: selectedDate,
        employees: allEmployees,
        shiftValuesByEmployeeId: shiftValuesByEmployeeId,
        originalShiftValuesByEmployeeId: originalShiftValuesByEmployeeId,
      );

      if (!mounted) return;

      setState(() {
        originalShiftValuesByEmployeeId = Map<String, double>.from(
          shiftValuesByEmployeeId,
        );
        hasUnsavedChanges = false;
      });

      final workedCount = workedCountFor(allEmployees);
      final totalShifts = totalShiftsFor(allEmployees);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Табель сохранён: $workedCount человек, ${formatShift(totalShifts)} смен',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorText = 'Ошибка сохранения табеля: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildDatePanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: isSaving || isAttendanceLoading
                ? null
                : () {
                    changeDate(selectedDate.subtract(const Duration(days: 1)));
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: isSaving ? null : pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F0),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white),
                ),
                child: Column(
                  children: [
                    Text(
                      shortDate(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: isSaving || isAttendanceLoading
                ? null
                : () {
                    changeDate(selectedDate.add(const Duration(days: 1)));
                  },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget buildWorkedSummaryPanel({
    required List<Employee> visibleEmployees,
  }) {
    final visibleWorked = workedCountFor(visibleEmployees);
    final totalShifts = totalShiftsFor(visibleEmployees);

    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              size: 21,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Вышли сегодня',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visibleWorked / ${visibleEmployees.length}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${formatShift(totalShifts)} смен',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSearch() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО или должности',
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
        fillColor: Colors.white.withValues(alpha: 0.86),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.textPrimary,
            width: 1.3,
          ),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget buildQuickActions(List<Employee> visibleEmployees) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Быстрый ввод',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed:
                visibleEmployees.isEmpty || isSaving || isAttendanceLoading
                ? null
                : () {
                    setVisibleEmployeesShifts(
                      employees: visibleEmployees,
                      value: 1,
                    );
                  },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Всем 1'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed:
                visibleEmployees.isEmpty || isSaving || isAttendanceLoading
                ? null
                : () {
                    setVisibleEmployeesShifts(
                      employees: visibleEmployees,
                      value: 0,
                    );
                  },
            icon: const Icon(Icons.remove_done, size: 18),
            label: const Text('Всем 0'),
          ),
        ],
      ),
    );
  }

  Widget buildEmployeeRow(Employee employee) {
    final shifts = shiftValueFor(employee);
    final hasWorked = shifts > 0;

    return PremiumWorkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      radius: 22,
      tint: hasWorked
          ? const Color(0xFFEDEEEB)
          : Colors.white.withValues(alpha: 0.86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.position,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: AppMotion.regular,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: hasWorked
                      ? AppColors.textPrimary
                      : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatShift(shifts),
                  style: TextStyle(
                    color: hasWorked ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...quickShiftOptions.map((option) {
                final isSelected = shifts == option;

                return ChoiceChip(
                  label: Text(formatShift(option)),
                  selected: isSelected,
                  onSelected: isAttendanceLoading || isSaving
                      ? null
                      : (_) {
                          setShiftValue(employee, option);
                        },
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: const Text('Другое'),
                onPressed: isAttendanceLoading || isSaving
                    ? null
                    : () {
                        showShiftPicker(employee);
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: FutureBuilder<List<Employee>>(
          future: employeesFuture,
          builder: (context, employeesSnapshot) {
            final allEmployees = employeesSnapshot.data ?? [];
            final visibleEmployees = filterEmployees(allEmployees);

            if (employeesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (employeesSnapshot.hasError) {
              return Center(
                child: Text(
                  'Ошибка загрузки сотрудников: ${employeesSnapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                        children: [
                          buildDatePanel(),
                          const SizedBox(height: 14),
                          buildWorkedSummaryPanel(
                            visibleEmployees: visibleEmployees,
                          ),
                          const SizedBox(height: 14),
                          buildSearch(),
                          const SizedBox(height: 14),
                          buildQuickActions(visibleEmployees),
                          const SizedBox(height: 16),
                          if (isAttendanceLoading || isSaving)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: LinearProgressIndicator(),
                            ),
                          if (errorText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                errorText!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (visibleEmployees.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: Text(
                                  'Сотрудники не найдены',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...visibleEmployees.map(
                              (employee) => RepaintBoundary(child: buildEmployeeRow(employee)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.94),
                        ),
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: PremiumActionButton(
                          label: hasUnsavedChanges
                              ? 'Сохранить изменения'
                              : 'Сохранить табель',
                          icon: Icons.save_outlined,
                          isLoading: isSaving,
                          onPressed:
                              allEmployees.isEmpty ||
                                  isAttendanceLoading ||
                                  isSaving
                              ? null
                              : () {
                                  saveTimesheet(allEmployees);
                                },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TimesheetReportRoute extends StatelessWidget {
  final String? selectedObjectName;

  const _TimesheetReportRoute({required this.selectedObjectName});

  String get objectTitle {
    final objectName = selectedObjectName?.trim();

    if (objectName == null || objectName.isEmpty) {
      return 'Все объекты';
    }

    return objectName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Отчет по табелю — $objectTitle')),
      body: PeriodTimesheetScreen(selectedObjectName: selectedObjectName),
    );
  }
}
