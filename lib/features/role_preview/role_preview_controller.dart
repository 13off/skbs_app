import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../navigation/navigation_session.dart';

class RolePreviewState {
  final String role;
  final String objectName;

  const RolePreviewState({
    this.role = 'admin',
    this.objectName = '',
  });

  bool get isAdminMode => role == 'admin';
  bool get isForemanMode => role == 'foreman';
  bool get isLawyerMode => role == 'lawyer';
  bool get isAccountantMode => role == 'accountant';

  String get title {
    switch (role) {
      case 'foreman':
        return 'Прораб';
      case 'lawyer':
        return 'Юрист';
      case 'accountant':
        return 'Бухгалтер';
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

    switch (savedRole) {
      case 'foreman':
        state.value = savedObjectName.isEmpty
            ? const RolePreviewState()
            : RolePreviewState(
                role: 'foreman',
                objectName: savedObjectName,
              );
      case 'lawyer':
        state.value = const RolePreviewState(role: 'lawyer');
      case 'accountant':
        state.value = const RolePreviewState(role: 'accountant');
      default:
        state.value = const RolePreviewState();
    }
  }

  static void setState(RolePreviewState nextState) {
    state.value = nextState;
    unawaited(
      NavigationSession.writePreview(
        role: nextState.role,
        objectName: nextState.objectName,
      ),
    );
  }

  static void showAdmin() {
    setState(const RolePreviewState());
  }

  static void showForeman({required String objectName}) {
    final cleanObjectName = objectName.trim();
    if (cleanObjectName.isEmpty) return;
    setState(
      RolePreviewState(
        role: 'foreman',
        objectName: cleanObjectName,
      ),
    );
  }

  static void showLawyer() {
    setState(const RolePreviewState(role: 'lawyer'));
  }

  static void showAccountant() {
    setState(const RolePreviewState(role: 'accountant'));
  }

  static void reset({bool clearPersisted = true}) {
    state.value = const RolePreviewState();
    if (clearPersisted) {
      unawaited(NavigationSession.clearPreview());
    }
  }
}
