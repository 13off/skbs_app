// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

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
    return timesheetDraft.valueFor(employee.id);
  }

  void setShiftValue(Employee employee, double value) {
    final nextDraft = timesheetDraft.withValue(employee.id, value);
    if (identical(nextDraft, timesheetDraft)) return;
    setState(() => timesheetDraft = nextDraft);
  }

  double totalShiftsFor(List<Employee> employees) {
    return timesheetDraft.totalFor(employees.map((employee) => employee.id));
  }

  int workedCountFor(List<Employee> employees) {
    return timesheetDraft.workedCountFor(
      employees.map((employee) => employee.id),
    );
  }

  TimesheetGroup? groupForEmployee(Employee employee) {
    for (final group in timesheetGroups) {
      if (group.containsEmployee(employee.id)) return group;
    }
    return null;
  }

  bool employeeMatchesGroupFilter(Employee employee) {
    if (selectedGroupFilter == _allTimesheetGroupsFilter) return true;
    return groupForEmployee(employee)?.id == selectedGroupFilter;
  }

  String timesheetGroupTitle(TimesheetGroup group) {
    if (cleanObjectName(widget.selectedObjectName) != null) return group.name;
    return '${group.name} · ${group.objectName}';
  }

  List<Employee> filterEmployees(List<Employee> employees) {
    final searchText = searchController.text.trim().toLowerCase();
    final result = employees.where((employee) {
      if (!employeeMatchesGroupFilter(employee)) return false;
      return searchText.isEmpty ||
          employee.name.toLowerCase().contains(searchText) ||
          employee.position.toLowerCase().contains(searchText);
    }).toList();
    result.sort((first, second) => first.name.compareTo(second.name));
    return result;
  }

  List<_TimesheetEmployeeGroupSection> employeeGroupSections(
    List<Employee> visibleEmployees,
  ) {
    if (timesheetGroups.isEmpty) {
      return <_TimesheetEmployeeGroupSection>[
        _TimesheetEmployeeGroupSection(
          title: 'Общая',
          employees: visibleEmployees,
        ),
      ];
    }

    final sections = <_TimesheetEmployeeGroupSection>[];
    for (final group in timesheetGroups) {
      if (selectedGroupFilter != _allTimesheetGroupsFilter &&
          selectedGroupFilter != group.id) {
        continue;
      }
      final members = visibleEmployees
          .where((employee) => group.containsEmployee(employee.id))
          .toList(growable: false);
      if (members.isNotEmpty) {
        sections.add(
          _TimesheetEmployeeGroupSection(
            title: timesheetGroupTitle(group),
            employees: members,
          ),
        );
      }
    }

    return sections;
  }

  Future<void> openTimesheetGroupManager(List<Employee> employees) async {
    if (!canManageTimesheetGroups) return;
    final changed = await TimesheetGroupManagerSheet.show(
      context,
      selectedObjectName: widget.selectedObjectName,
      employees: employees,
      groups: timesheetGroups,
    );
    if (changed && mounted) {
      selectedGroupFilter = _allTimesheetGroupsFilter;
      await loadTimesheetGroups(forceRefresh: true);
    }
  }

  Future<void> changeDate(DateTime newDate) async {
    setState(() {
      selectedDate = DateTime(newDate.year, newDate.month, newDate.day);
      timesheetDraft = TimesheetDraft.empty();
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
    final nextDraft = timesheetDraft.withValues(
      employees.map((employee) => employee.id),
      value,
    );
    if (identical(nextDraft, timesheetDraft)) return;
    setState(() => timesheetDraft = nextDraft);
  }

  Future<void> showShiftPicker(Employee employee) async {
    final employeeId = employee.id;
    if (employeeId == null) return;

    final currentValue = timesheetDraft.valueFor(employeeId);
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
        shiftValuesByEmployeeId: timesheetDraft.values,
        originalShiftValuesByEmployeeId: timesheetDraft.originalValues,
      );

      if (!mounted) return;
      setState(() => timesheetDraft = timesheetDraft.markSaved());
      final responsibility =
          await AttendanceRepository.fetchResponsibilityForDate(
            selectedDate,
            objectName: widget.selectedObjectName,
            forceRefresh: true,
          );
      if (!mounted) return;
      setState(() => attendanceResponsibility = responsibility);

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
