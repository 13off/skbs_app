import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/app_user_profile.dart';
import 'profile_repository.dart';

class PersonalProfileController {
  PersonalProfileController._();

  static final ValueNotifier<PersonalProfileData> state =
      ValueNotifier<PersonalProfileData>(PersonalProfileData.empty);

  static String configuredUserId = '';
  static Future<void>? loadingFuture;

  static void configure(AppUserProfile profile) {
    final nextUserId = profile.id.trim();
    if (nextUserId.isEmpty) {
      reset();
      return;
    }

    if (configuredUserId != nextUserId) {
      configuredUserId = nextUserId;
      loadingFuture = null;
      state.value = PersonalProfileData(
        fullName: profile.fullName.trim(),
        phone: profile.phone.trim(),
        avatarPath: profile.avatarPath.trim(),
      );
    }

    unawaited(refresh());
  }

  static Future<void> refresh({bool force = false}) {
    if (configuredUserId.isEmpty) return Future<void>.value();
    if (!force && loadingFuture != null) return loadingFuture!;

    final expectedUserId = configuredUserId;
    late final Future<void> future;
    future = () async {
      try {
        final value = await ProfileRepository.fetchPersonalData();
        if (configuredUserId != expectedUserId) return;
        state.value = value;
      } catch (_) {
        // Базовый профиль уже показан. Следующее открытие повторит загрузку.
      }
    }().whenComplete(() {
      if (identical(loadingFuture, future)) loadingFuture = null;
    });
    loadingFuture = future;
    return future;
  }

  static void apply(PersonalProfileData value) {
    if (configuredUserId.isEmpty) return;
    state.value = value;
  }

  static AppUserProfile merge(AppUserProfile profile) {
    if (profile.id.trim() != configuredUserId) return profile;
    final personal = state.value;
    return profile.copyWith(
      fullName: personal.fullName.isEmpty
          ? profile.fullName
          : personal.fullName,
      phone: personal.phone,
      avatarPath: personal.avatarPath,
    );
  }

  static void reset() {
    configuredUserId = '';
    loadingFuture = null;
    state.value = PersonalProfileData.empty;
  }
}
