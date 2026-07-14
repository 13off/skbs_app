import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test(
    'invitation link bypasses localhost and uses a production token flow',
    () {
      final repository = source('lib/features/auth/data/user_repository.dart');
      final gate = source(
        'lib/features/auth/presentation/premium_auth_gate_v2.dart',
      );
      final edge = source('supabase/functions/invite-company-member/index.ts');

      expect(edge, contains('https://api.appstroy-web.ru/app/'));
      expect(edge, contains('invite.html'));
      expect(edge, contains('inviteTokenHash'));
      expect(edge, contains('inviteType'));
      expect(edge, contains('properties?.hashed_token'));
      expect(
        edge,
        isNot(contains('actionLink = linkData.properties?.action_link')),
      );

      expect(repository, contains('verifyPendingInvitationLink'));
      expect(repository, contains('verifyOTP('));
      expect(repository, contains('tokenHash: tokenHash'));
      expect(repository, contains('OtpType.invite'));
      expect(repository, contains('OtpType.recovery'));
      expect(repository, contains('OtpType.magiclink'));

      final verifyIndex = gate.indexOf(
        'await UserRepository.verifyPendingInvitationLink()',
      );
      final sessionIndex = gate.indexOf(
        'final session = UserRepository.currentSession;',
      );
      expect(verifyIndex, greaterThanOrEqualTo(0));
      expect(sessionIndex, greaterThan(verifyIndex));
    },
  );

  test(
    'production invitation page consumes the token only after user action',
    () {
      final invitePage = source('web/invite.html');

      expect(invitePage, contains('<button id="accept" type="button">'));
      expect(
        invitePage,
        contains("accept.addEventListener('click', acceptInvitation)"),
      );
      expect(invitePage, contains('async function acceptInvitation()'));
      expect(invitePage, contains('/auth/v1/verify'));
      expect(invitePage, contains("token_hash: tokenHash"));
      expect(invitePage, contains('progress hidden'));

      expect(invitePage, isNot(contains('(async function ()')));
      expect(invitePage, isNot(contains('acceptInvitation();')));
    },
  );
}
