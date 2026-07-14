import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation link bypasses localhost redirect and verifies token in app', () {
    final repository = source(
      'lib/features/auth/data/user_repository.dart',
    );
    final gate = source(
      'lib/features/auth/presentation/premium_auth_gate_v2.dart',
    );
    final edge = source(
      'supabase/functions/invite-company-member/index.ts',
    );

    expect(edge, contains('https://13off.github.io/appstroy-web/'));
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
  });
}
