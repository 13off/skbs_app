import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company invitations are rewritten to the static landing route', () {
    final repository = source('lib/features/auth/data/user_repository.dart');
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final core = source(
      'supabase/functions/invite-company-member-core/index.ts',
    );

    final methodStart = repository.indexOf(
      'static String buildInvitationRedirectUrl',
    );
    final methodEnd = repository.indexOf(
      'static Future<bool> verifyPendingInvitationLink',
      methodStart,
    );
    final redirectMethod = repository.substring(methodStart, methodEnd);

    expect(redirectMethod, contains('Uri.parse(_fallbackWebAppUrl)'));
    expect(redirectMethod, isNot(contains('Uri.base')));

    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('https://13off.github.io/appstroy-web/'));
    expect(edge, contains('publicInvitationUrl'));
    expect(edge, contains('publicRedirectUrl'));
    expect(edge, contains('result.invite_url = publicInvitationUrl'));
    expect(edge, contains('result.redirect_to = publicRedirectUrl'));
    expect(edge, isNot(contains('input.redirect_to')));
    expect(edge, isNot(contains('localhost')));

    // The core still owns the token and tenant-safe invitation creation.
    expect(core, contains('invitationActionUrl'));
    expect(core, contains('redirect_to: invitationRedirectUrl(companyId)'));
  });
}
