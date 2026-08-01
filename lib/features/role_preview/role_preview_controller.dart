import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../navigation/navigation_session.dart';

class RolePreviewState {
  final String role;
  final String objectName;
  final String employeeId;
  final String employeeName;

  const RolePreviewState({
    this.role = 'admin',
    this.objectName = '',
    this.employeeId = '',
    this.employeeName = '',
  });

  bool get isAdminMode => role == 'admin';
  bool get isDeveloperMode => role == 'developer';
  bool get isForemanMode => role == 'foreman';
  bool get isEmployeeMode => role == 'employee';
  bool get isLawyerMode => role == 'lawyer';
  bool get isAccountantMode => role == 'accountant';
  bool get isHrMode => role == 'hr';
  bool get isProcurementMode => role == 'procurement';

  String get title {
    switch (role) {
      case 'developer':
        return 'Разработчик';
      case 'foreman':
        return 'Прораб';
      case 'employee':
        return 'Сотрудник';
      case 'lawyer':
        return 'Юрист';
      case 'accountant':
        return 'Бухгалтер';
      case 'hr':
        return 'HR-менеджер';
      case 'procurement':
        return 'Снабженец';
      default:
        return 'Руководитель';
    }
  }
}

class RolePreviewController {
  static final ValueNotifier<RolePreviewState> state =
      ValueNotifier<RolePreviewState>(const RolePreviewState());

  static Future<void> restore({required bool canPreviewRoles}) async {
    if (!canPreviewRoles) {
      state.value = const RolePreviewState();
      return;
    }

    final savedRole = NavigationSession.readPreviewRole()?.trim();
    final savedObjectName = NavigationSession.readPreviewObjectName();
    final savedEmployeeId = NavigationSession.readPreviewEmployeeId();
    final savedEmployeeName = NavigationSession.readPreviewEmployeeName();

    if (savedRole == 'developer') {
      state.value = const RolePreviewState(role: 'developer');
      return;
    }
    if (savedRole == 'foreman' && savedObjectName.isNotEmpty) {
      state.value = RolePreviewState(
        role: 'foreman',
        objectName: savedObjectName,
      );
      return;
    }
    if (savedRole == 'employee' && savedEmployeeId.isNotEmpty) {
      state.value = RolePreviewState(
        role: 'employee',
        employeeId: savedEmployeeId,
        employeeName: savedEmployeeName,
      );
      return;
    }
    if (savedRole == 'lawyer') {
      state.value = const RolePreviewState(role: 'lawyer');
      return;
    }
    if (savedRole == 'accountant') {
      state.value = const RolePreviewState(role: 'accountant');
      return;
    }
    if (savedRole == 'hr') {
      state.value = const RolePreviewState(role: 'hr');
      return;
    }
    if (savedRole == 'procurement') {
      state.value = const RolePreviewState(role: 'procurement');
      return;
    }

    state.value = const RolePreviewState();
  }

  static void setState(RolePreviewState nextState) {
    state.value = nextState;
    unawaited(
      NavigationSession.writePreview(
        role: nextState.role,
        objectName: nextState.objectName,
        employeeId: nextState.employeeId,
        employeeName: nextState.employeeName,
      ),
    );
  }

  static void showAdmin() {
    setState(const RolePreviewState());
  }

  static void showDeveloper() {
    setState(const RolePreviewState(role: 'developer'));
  }

  static void showForeman({required String objectName}) {
    final cleanObjectName = objectName.trim();
    if (cleanObjectName.isEmpty) return;
    setState(RolePreviewState(role: 'foreman', objectName: cleanObjectName));
  }

  static void showEmployee({
    required String employeeId,
    required String employeeName,
  }) {
    final cleanEmployeeId = employeeId.trim();
    if (cleanEmployeeId.isEmpty) return;
    setState(
      RolePreviewState(
        role: 'employee',
        employeeId: cleanEmployeeId,
        employeeName: employeeName.trim(),
      ),
    );
  }

  static void showLawyer() {
    setState(const RolePreviewState(role: 'lawyer'));
  }

  static void showAccountant() {
    setState(const RolePreviewState(role: 'accountant'));
  }

  static void showHr() {
    setState(const RolePreviewState(role: 'hr'));
  }

  static void showProcurement() {
    setState(const RolePreviewState(role: 'procurement'));
  }

  static void reset({bool clearPersisted = true}) {
    state.value = const RolePreviewState();
    if (clearPersisted) {
      unawaited(NavigationSession.clearPreview());
    }
  }
}
