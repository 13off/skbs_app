import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal profile reads the canonical linked person identity', () {
    final repository = File(
      'lib/features/profile/data/profile_repository.dart',
    ).readAsStringSync();

    expect(repository, contains("rpc('get_current_user_personal_profile')"));
    expect(
      repository,
      isNot(
        contains(
          ".from('user_profiles')\n        .select('full_name, phone, avatar_path')",
        ),
      ),
    );
  });

  test('company roles can be linked to one employee identity safely', () {
    final migration = File(
      'supabase/migrations/20260801102026_sync_role_profiles_with_people.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists person_id uuid'));
    expect(migration, contains('company_memberships_person_id_fkey'));
    expect(migration, contains('private.guard_company_membership_person'));
    expect(migration, contains("coalesce(auth.role(), '') <> 'service_role'"));
    expect(migration, contains('private.resolve_company_person_identity'));
    expect(migration, contains('public.get_current_user_personal_profile'));
  });

  test('employee edits synchronize linked role profiles in both directions', () {
    final migration = File(
      'supabase/migrations/20260801102026_sync_role_profiles_with_people.sql',
    ).readAsStringSync();

    expect(migration, contains('private.sync_person_to_user_profiles'));
    expect(migration, contains('private.sync_employee_personal_fields'));
    expect(migration, contains('public.update_current_user_profile'));
    expect(migration, contains('select cm.person_id'));
    expect(migration, contains('select eal.person_id'));
    expect(
      migration,
      isNot(
        contains(
          'v_person_id := private.resolve_company_person_identity(\n        v_company_id,\n        v_full_name',
        ),
      ),
    );
  });
}
