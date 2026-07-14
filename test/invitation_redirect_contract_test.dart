import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company invitations always return to the production web app', () {
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
    expect(edge, contains('function invitationRedirectUrl(companyId: string)'));
    expect(edge, contains('new URL(defaultWebAppUrl)'));
    expect(edge, contains('invitationRedirectUrl(companyId)'));
    expect(edge, isNot(contains('url.hostname === "localhost"')));
    expect(edge, isNot(contains('input.redirect_to')));
  });
}
