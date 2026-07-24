import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Контракт также запускает штатную Web/PWA-публикацию после слияния.
void main() {
  test('profile stays personal and opens the unified settings center', () {
    final profile = File('lib/screens/profile_screen.dart').readAsStringSync();

    expect(profile, contains("title: 'Профиль'"));
    expect(profile, contains("title: 'ФИО'"));
    expect(profile, contains("title: 'Номер телефона'"));
    expect(profile, contains('pickPhoto()'));
    expect(profile, contains('editPersonalData()'));
    expect(profile, contains('SettingsScreen(profile: settingsProfile())'));
    expect(profile, isNot(contains("title: 'Email'")));
    expect(profile, isNot(contains("sectionTitle('Уведомления')")));
    expect(profile, isNot(contains("sectionTitle('Управление компанией')")));
  });

  test('settings combine common controls with role-specific real screens', () {
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(settings, contains("title: 'Настройки'"));
    expect(settings, contains("sectionTitle('Интерфейс')"));
    expect(settings, contains("sectionTitle('Уведомления')"));
    expect(settings, contains("sectionTitle('Настройки профессии')"));
    expect(settings, contains('RecruitmentCrmSettingsScreen(profile: profile)'));
    expect(settings, contains('DeveloperPanelScreen(profile: profile)'));
    expect(settings, contains('RolePermissionMatrixScreen'));
    expect(settings, contains('CompanyManagementScreen'));
  });

  test('personal profile data is protected by authenticated RPC and storage', () {
    final repository = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260724190000_profile_personal_data.sql',
    ).readAsStringSync();

    expect(repository, contains("avatarBucket = 'profile-avatars'"));
    expect(repository, contains("'update_current_user_profile'"));
    expect(repository, contains('maximumAvatarBytes = 5 * 1024 * 1024'));
    expect(migration, contains('security definer'));
    expect(migration, contains('auth.uid()'));
    expect(migration, contains("bucket_id = 'profile-avatars'"));
    expect(migration, contains('revoke all on function'));
    expect(migration, contains('to authenticated'));
  });
}
