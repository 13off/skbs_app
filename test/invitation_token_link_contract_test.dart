import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation link uses the canonical published page without localhost', () {
    final repository = source('lib/features/auth/data/user_repository.dart');
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final core = source(
      'supabase/functions/invite-company-member-core/index.ts',
    );
    final landing = source('web/invite.html');

    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('return json(data, coreResponse.status);'));
    expect(edge, isNot(contains('13off.github.io/appstroy-web')));
    expect(edge, isNot(contains('publishedWebAppUrl')));
    expect(core, contains('https://api.appstroy-web.ru/app/'));
    expect(core, contains('invitationActionUrl'));
    expect(core, contains('inviteTokenHash'));
    expect(core, contains('inviteType'));
    expect(edge, isNot(contains('/functions/v1/invite-landing')));
    expect(edge, isNot(contains('localhost')));

    expect(landing, contains('/auth/v1/verify'));
    expect(landing, contains('token_hash: tokenHash'));
    expect(
      landing,
      contains("const supabaseUrl = 'https://api.appstroy-web.ru'"),
    );

    expect(repository, contains('verifyPendingInvitationLink'));
    expect(repository, contains('verifyOTP('));
    expect(repository, contains('tokenHash: tokenHash'));
    expect(repository, contains('accept_current_company_invitation'));
    expect(repository, contains('https://api.appstroy-web.ru/app/'));

    final verifyIndex = gate.indexOf(
      'await UserRepository.verifyPendingInvitationLink()',
    );
    final sessionIndex = gate.indexOf(
      'final session = UserRepository.currentSession;',
    );
    expect(verifyIndex, greaterThanOrEqualTo(0));
    expect(sessionIndex, greaterThan(verifyIndex));
  });

  test('static landing consumes the token only after explicit user action', () {
    final landing = source('web/invite.html');

    expect(landing, contains('id="accept" type="button"'));
    expect(
      landing,
      contains("accept.addEventListener('click', acceptInvitation)"),
    );
    expect(landing, contains('async function acceptInvitation()'));
    expect(landing, contains('/auth/v1/verify'));
    expect(landing, contains('class="progress hidden"'));
    expect(landing, isNot(contains('acceptInvitation();')));
  });
}
