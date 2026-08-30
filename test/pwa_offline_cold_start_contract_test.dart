import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA restores the last authenticated profile before server refresh', () {
    final rootGate = File('lib/screens/auth_gate.dart').readAsStringSync();
    final offlineGate = File(
      'lib/features/auth/presentation/offline_first_auth_gate.dart',
    ).readAsStringSync();
    final store = File(
      'lib/features/auth/data/offline_profile_store.dart',
    ).readAsStringSync();

    expect(rootGate, contains('class AuthGate extends OfflineFirstAuthGate'));
    expect(offlineGate, contains('OfflineProfileStore.read(user.id)'));
    expect(offlineGate, contains('return MainScreen(profile: profile)'));
    expect(offlineGate, contains('fetchCurrentProfile('));
    expect(offlineGate, contains('.timeout(_profileRefreshTimeout)'));
    expect(offlineGate, contains('OfflineProfileStore.save(refreshed)'));
    expect(store, contains('SharedPreferences.getInstance()'));
    expect(store, contains("'active_company_id': profile.activeCompanyId"));
  });

  test('offline cold start keeps invitation and password flows online-owned', () {
    final offlineGate = File(
      'lib/features/auth/presentation/offline_first_auth_gate.dart',
    ).readAsStringSync();

    expect(offlineGate, contains('UserRepository.mustSetPassword'));
    expect(offlineGate, contains("containsKey('companyInvite')"));
    expect(offlineGate, contains("containsKey('inviteTokenHash')"));
    expect(offlineGate, contains("Uri.base.queryParameters['privateImport'] == '1'"));
    expect(offlineGate, contains('return const legacy.AuthGate()'));
  });
}
