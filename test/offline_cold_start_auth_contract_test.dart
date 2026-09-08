import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-in mobile startup restores cached profile before server refresh', () {
    final gate = File(
      'lib/features/auth/presentation/offline_first_auth_gate.dart',
    ).readAsStringSync();
    final splash = File(
      'lib/features/company/presentation/company_brand_splash_host.dart',
    ).readAsStringSync();
    final mainScreen = File('lib/screens/main_screen.dart').readAsStringSync();

    final cachedRead = gate.indexOf('OfflineProfileStore.read(user.id)');
    final refresh = gate.indexOf(
      'unawaited(_refreshFromServer(user.id, generation, forceRefresh))',
    );
    expect(cachedRead, greaterThanOrEqualTo(0));
    expect(refresh, greaterThan(cachedRead));
    expect(gate, contains('_profileRefreshTimeout = Duration(seconds: 4)'));
    expect(
      gate,
      contains('При полном отсутствии сети сохранённый профиль остаётся рабочим.'),
    );
    expect(gate, contains('return MainScreen(profile: profile);'));

    final splashCachedRead = splash.indexOf('OfflineProfileStore.read(user.id)');
    final splashRemoteRead = splash.indexOf(".from('user_profiles')");
    expect(splashCachedRead, greaterThanOrEqualTo(0));
    expect(splashRemoteRead, greaterThan(splashCachedRead));
    expect(
      splash,
      contains('При отсутствии сети используем кэш профиля, если он есть.'),
    );

    expect(mainScreen, contains('OfflineSyncHost('));
    expect(mainScreen, contains('userId: widget.profile.id'));
    expect(mainScreen, contains('companyId: widget.profile.activeCompanyId'));
  });
}
