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
      final values = await AttendanceRepository.fetchShiftValuesForDate(
        requestedDate,
        objectName: requestedObject,
        forceRefresh: forceRefresh,
      );

      if (!mounted || generation != attendanceLoadGeneration) return;

      setState(() {
        shiftValuesByEmployeeId = Map<String, double>.from(values);
        originalShiftValuesByEmployeeId = Map<String, double>.from(values);
        hasUnsavedChanges = false;
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
