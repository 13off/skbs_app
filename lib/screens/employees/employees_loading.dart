part of '../employees_screen.dart';

extension _EmployeesLoading on _EmployeesScreenState {
  String? get objectName => directoryController.objectName;

  Future<void> loadEmployees({
    bool showLoading = false,
    bool forceRefresh = false,
  }) {
    return directoryController.load(
      showLoading: showLoading,
      forceRefresh: forceRefresh,
    );
  }
}
