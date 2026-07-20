part of '../timesheet_screen.dart';

extension _TimesheetActions on _TimesheetScreenState {
  String formatShift(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  String shortDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String weekDayName(DateTime date) {
    const names = <String>[
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
      return searchText.isEmpty ||
          employee.name.toLowerCase().contains(searchText) ||
          employee.position.toLowerCase().contains(searchText);
    }).toList();
  }

  Future<void> changeDate(DateTime newDate) async {
    setState(() {
      selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      shiftValuesByEmployeeId = <String, double>{};
      originalShiftValuesByEmployeeId = <String, double>{};
      hasUnsavedChanges = false;
      hasPendingRemoteAttendance = false;
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
    var selectedValue = currentValue;

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
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка сохранения табеля: $error');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
        scheduleMicrotask(applyPendingRemoteAttendance);
      }
    }
  }
}
