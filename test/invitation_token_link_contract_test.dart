import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation link uses the Russian Edge route without localhost', () {
    final repository = source('lib/features/auth/data/user_repository.dart');
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final landing = source('supabase/functions/invite-landing/index.ts');

    expect(
      edge,
      contains(
        'https://api.appstroy-web.ru/functions/v1/invite-landing',
      ),
    );
    expect(edge, contains('companyInvite'));
    expect(edge, contains('inviteTokenHash'));
    expect(edge, contains('inviteType'));
    expect(edge, isNot(contains('github.io')));
    expect(edge, isNot(contains('/app/invite.html')));

    expect(landing, contains("api('/auth/v1/verify'"));
    expect(landing, contains('token_hash: settings.tokenHash'));
    expect(landing, contains("api('/rest/v1/rpc/set_active_company'"));
    expect(
      landing,
      contains("api('/rest/v1/rpc/accept_current_company_invitation'"),
    );
    expect(landing, contains("api('/auth/v1/user'"));

    expect(repository, contains('verifyPendingInvitationLink'));
    expect(repository, contains('verifyOTP('));
    expect(repository, contains('tokenHash: tokenHash'));

    final verifyIndex = gate.indexOf(
      'await UserRepository.verifyPendingInvitationLink()',
    );
    final sessionIndex = gate.indexOf(
      'final session = UserRepository.currentSession;',
    );
    expect(verifyIndex, greaterThanOrEqualTo(0));
    expect(sessionIndex, greaterThan(verifyIndex));
  });

  test('Edge landing consumes the token only after explicit user action', () {
    final landing = source('supabase/functions/invite-landing/index.ts');

    expect(landing, contains('id="accept" type="button"'));
    expect(
      landing,
      contains("acceptButton.addEventListener('click', acceptInvitation)"),
    );
    expect(landing, contains('async function acceptInvitation()'));
    expect(landing, contains("api('/auth/v1/verify'"));
    expect(landing, contains('class="progress hidden"'));
    expect(landing, isNot(contains('acceptInvitation();')));
  });
}
