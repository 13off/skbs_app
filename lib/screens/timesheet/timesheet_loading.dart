// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../timesheet_screen.dart';

extension _TimesheetLoading on _TimesheetScreenState {
  void reloadEmployees({bool forceRefresh = false}) {
    employeesFuture = EmployeeRepository.fetchEmployees(
      objectName: widget.selectedObjectName,
      forceRefresh: forceRefresh,
    );
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  String get objectTitle =>
      cleanObjectName(widget.selectedObjectName) ?? 'Все объекты';

  Future<void> loadTimesheetGroups({bool forceRefresh = false}) async {
    if (mounted) setState(() => isGroupsLoading = true);
    try {
      final groups = await TimesheetGroupRepository.fetchGroups(
        objectName: widget.selectedObjectName,
      );
      if (!mounted) return;
      setState(() {
        timesheetGroups = groups;
        final filterExists =
            selectedGroupFilter == _allTimesheetGroupsFilter ||
            groups.any((group) => group.id == selectedGroupFilter);
        if (!filterExists) {
          selectedGroupFilter = _allTimesheetGroupsFilter;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = 'Ошибка загрузки групп табеля: $error');
    } finally {
      if (mounted) setState(() => isGroupsLoading = false);
    }
  }

  Future<void> loadAttendance({bool forceRefresh = false}) async {
    final generation = ++attendanceLoadGeneration;
    final requestedDate = selectedDate;
    final requestedObject = widget.selectedObjectName;
    hasPendingRemoteAttendance = false;

    setState(() {
      isAttendanceLoading = true;
      errorText = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        AttendanceRepository.fetchShiftValuesForDate(
          requestedDate,
          objectName: requestedObject,
          forceRefresh: forceRefresh,
        ),
        AttendanceRepository.fetchResponsibilityForDate(
          requestedDate,
          objectName: requestedObject,
          forceRefresh: forceRefresh,
        ),
      ]);
      final values = results[0] as Map<String, double>;
      final responsibility = results[1] as Map<String, ResponsibilityActor>;

      if (!mounted || generation != attendanceLoadGeneration) return;
      setState(() {
        timesheetDraft = TimesheetDraft.fromValues(values);
        attendanceResponsibility = responsibility;
      });
    } catch (error) {
      if (!mounted || generation != attendanceLoadGeneration) return;
      setState(() => errorText = 'Ошибка загрузки табеля: $error');
    } finally {
      if (mounted && generation == attendanceLoadGeneration) {
        setState(() => isAttendanceLoading = false);
        scheduleMicrotask(applyPendingRemoteAttendance);
      }
    }
  }
}
