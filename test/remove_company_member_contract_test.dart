import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('admin can remove a non-owner member from one company', () {
    final screen = source(
      'lib/features/company/presentation/mobile_company_management_screen.dart',
    );
    final repository = source(
      'lib/features/company/data/company_repository.dart',
    );
    final migration = source(
      'supabase/migrations/20260714093000_add_remove_company_member_rpc.sql',
    );

    expect(screen, contains("'Удалить из компании'"));
    expect(screen, contains("'Удалить пользователя?'"));
    expect(screen, contains('CompanyRepository.removeMember('));
    expect(repository, contains("'remove_company_member'"));
    expect(repository, contains("'p_company_id'"));
    expect(repository, contains("'p_user_id'"));

    expect(migration, contains("v_actor_role not in ('owner', 'admin')"));
    expect(migration, contains("v_target_role = 'owner'"));
    expect(migration, contains('p_user_id = v_actor_id'));
    expect(migration, contains('delete from public.object_memberships'));
    expect(migration, contains('delete from public.company_memberships'));
    expect(migration, contains("status = 'revoked'"));
    expect(migration, contains('grant execute on function'));
  });
}
