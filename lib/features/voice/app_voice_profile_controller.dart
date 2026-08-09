import 'package:flutter/foundation.dart';

import '../../models/app_user_profile.dart';

class AppVoiceProfileController {
  AppVoiceProfileController._();

  static final ValueNotifier<AppUserProfile?> state =
      ValueNotifier<AppUserProfile?>(null);

  static void configure(AppUserProfile profile) {
    final current = state.value;
    if (current != null && _sameContext(current, profile)) return;
    state.value = profile;
  }

  static void clearIfUser(String userId) {
    final current = state.value;
    if (current == null || current.id != userId) return;
    state.value = null;
  }

  static bool _sameContext(AppUserProfile left, AppUserProfile right) {
    return left.id == right.id &&
        left.role == right.role &&
        left.actualRole == right.actualRole &&
        left.activeCompanyId == right.activeCompanyId &&
        left.objectName == right.objectName &&
        left.fullName == right.fullName;
  }
}
