part of '../timesheet_screen.dart';

extension _TimesheetSync on _TimesheetScreenState {
  bool changeMatchesCurrentTimesheet(AppDataChange change) {
    final workDate = change.contextValue('work_date');
    if (workDate != null &&
        workDate != AttendanceRepository.dateKey(selectedDate)) {
      return false;
    }

    final selectedObject = cleanObjectName(widget.selectedObjectName);
    final changedObject = cleanObjectName(change.contextValue('object_name'));

    return selectedObject == null ||
        changedObject == null ||
        selectedObject == changedObject;
  }

  void handleDataChange(AppDataChange change) {
    if (!mounted) return;

    if (change.affectsAny(const <AppDataDomain>{
      AppDataDomain.employees,
      AppDataDomain.objects,
    })) {
      setState(() => reloadEmployees(forceRefresh: true));
    }

    final attendanceChanged = change.affectsAny(const <AppDataDomain>{
      AppDataDomain.attendance,
      AppDataDomain.objects,
    });

    if (!attendanceChanged ||
        !change.isRemote ||
        !changeMatchesCurrentTimesheet(change)) {
      return;
    }

    if (hasUnsavedChanges || isSaving || isAttendanceLoading) {
      hasPendingRemoteAttendance = true;
      return;
    }

    loadAttendance(forceRefresh: true);
  }

  void applyPendingRemoteAttendance() {
    if (!mounted ||
        !hasPendingRemoteAttendance ||
        hasUnsavedChanges ||
        isSaving ||
        isAttendanceLoading) {
      return;
    }

    loadAttendance(forceRefresh: true);
  }
}
