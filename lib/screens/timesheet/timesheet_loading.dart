// State helpers below are part of the owning screen library and intentionally
// update that exact State instance.
// ignore_for_file: invalid_use_of_protected_member

part of '../timesheet_screen.dart';

extension _TimesheetLoading on _TimesheetScreenState {
  void reloadEmployees({bool forceRefresh = false}) {
    employeesFuture = OfflineEmployeeRepository.fetchEmployees(
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

  String? get timesheetPolicyObject =>
      cleanObjectName(widget.selectedObjectName) ??
      cleanObjectName(widget.profile.objectName);

  Future<void> loadTimesheetPolicy({bool forceRefresh = false}) async {
    if (!isForemanTimesheetRestrictionActive) {
      if (!mounted) return;
      setState(() {
        timesheetPolicy = TaskPolicy.defaults;
        timesheetPolicyObjectName = timesheetPolicyObject;
        hasTimesheetPolicy = true;
        isTimesheetPolicyLoading = false;
      });
      return;
    }

    final objectName = timesheetPolicyObject;
    if (objectName == null) {
      if (!mounted) return;
      setState(() {
        timesheetPolicyObjectName = null;
        hasTimesheetPolicy = false;
        isTimesheetPolicyLoading = false;
      });
      return;
    }

    if (mounted) setState(() => isTimesheetPolicyLoading = true);
    try {
      final policy = await DeveloperPolicyRepository.ensurePolicy(
        objectName,
        forceRefresh: forceRefresh,
      );
      if (!mounted || timesheetPolicyObject != objectName) return;
      setState(() {
        timesheetPolicy = policy;
        timesheetPolicyObjectName = objectName;
        hasTimesheetPolicy = true;
      });
    } catch (_) {
      if (!mounted || timesheetPolicyObject != objectName) return;
      setState(() {
        final hasSameObjectPolicy =
            hasTimesheetPolicy && timesheetPolicyObjectName == objectName;
        hasTimesheetPolicy = hasSameObjectPolicy;
      });
    } finally {
      if (mounted && timesheetPolicyObject == objectName) {
        setState(() => isTimesheetPolicyLoading = false);
      }
    }
  }

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
      // Группы — вспомогательная функция. При плохой связи табель остаётся
      // доступным по локальному списку сотрудников без блокирующей ошибки.
      setState(() {
        timesheetGroups = const <TimesheetGroup>[];
        selectedGroupFilter = _allTimesheetGroupsFilter;
      });
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
        OfflineAttendanceRepository.fetchShiftValuesForDate(
          requestedDate,
          objectName: requestedObject,
          forceRefresh: forceRefresh,
        ),
        OfflineAttendanceRepository.fetchResponsibilityForDate(
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
      setState(() => errorText = 'Не удалось открыть сохранённый табель: $error');
    } finally {
      if (mounted && generation == attendanceLoadGeneration) {
        setState(() => isAttendanceLoading = false);
        scheduleMicrotask(applyPendingRemoteAttendance);
      }
    }
  }
}
