import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('admin receives a copyable company invitation link', () {
    final screen = source(
      'lib/features/company/presentation/company_management_screen.dart',
    );
    final repository = source(
      'lib/features/company/data/company_repository.dart',
    );

    expect(screen, contains("'Ссылка приглашения готова'"));
    expect(screen, contains('Clipboard.setData'));
    expect(screen, contains("'Создать ссылку'"));
    expect(repository, contains("'redirect_to'"));
    expect(repository, contains("data['invite_url']"));
  });

  test('edge adapter preserves invitation core and rewrites only the route', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final core = source(
      'supabase/functions/invite-company-member-core/index.ts',
    );

    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('/functions/v1/invite-landing'));
    expect(edge, contains('companyInvite'));
    expect(edge, contains('inviteTokenHash'));
    expect(edge, contains('inviteType'));
    expect(edge, contains('...data'));
    expect(core, contains('generateLink'));
    expect(core, contains('type: "invite"'));
    expect(core, contains('"recovery"'));
    expect(core, contains('"magiclink"'));
    expect(core, contains('invite_url: actionLink'));
    expect(core, contains('"lawyer"'));
    expect(core, contains('"accountant"'));
    expect(edge, isNot(contains('inviteUserByEmail')));
    expect(edge, isNot(contains('resetPasswordForEmail')));
  });

  test('invitation link activates its company before profile loading', () {
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );

    final applyIndex = gate.indexOf('applyPendingInvitationCompany()');
    final profileIndex = gate.indexOf('fetchCurrentProfile(');
    expect(applyIndex, greaterThan(-1));
    expect(profileIndex, greaterThan(applyIndex));
    expect(gate, contains('AuthChangeEvent.passwordRecovery'));

    expect(repository, contains("_invitationCompanyParameter = 'companyInvite'"));
    expect(repository, contains('await setActiveCompany(companyId)'));
    expect(repository, contains('accept_current_company_invitation'));
    expect(repository, contains('history.replaceState'));
  });

  test('repeat login restores a missing active company from membership', () {
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );

    expect(repository, contains(".from('company_memberships')"));
    expect(repository, contains(".select('company_id')"));
    expect(repository, contains("'set_active_company'"));
    expect(repository, contains('await _client.auth.refreshSession()'));
    expect(repository, contains('static Session? get currentSession'));
  });
}
