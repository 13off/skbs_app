import 'package:flutter/foundation.dart';

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

  static void showAdmin() {
    state.value = const RolePreviewState();
  }

  static void showForeman({required String objectName}) {
    final cleanObjectName = objectName.trim();
    if (cleanObjectName.isEmpty) return;
    state.value = RolePreviewState(
      role: 'foreman',
      objectName: cleanObjectName,
    );
  }

  static void showLawyer() {
    state.value = const RolePreviewState(role: 'lawyer');
  }

  static void showAccountant() {
    state.value = const RolePreviewState(role: 'accountant');
  }

  static void reset() {
    showAdmin();
  }
}
