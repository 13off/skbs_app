import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company invitations use the published static landing route', () {
    final repository = source('lib/features/auth/data/user_repository.dart');
    final edge = source('supabase/functions/invite-company-member/index.ts');

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
    expect(edge, contains('new URL("invite.html", publishedWebAppUrl)'));
    expect(edge, contains('redirect_to: redirectUrl.toString()'));
    expect(edge, isNot(contains('/functions/v1/invite-landing')));
    expect(edge, isNot(contains('input.redirect_to')));
    expect(edge, isNot(contains('localhost')));
  });
}
