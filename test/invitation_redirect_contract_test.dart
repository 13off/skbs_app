import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('company invitations use one canonical published landing route', () {
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
    expect(redirectMethod, contains('https://api.appstroy-web.ru/app/'));
    expect(redirectMethod, isNot(contains('Uri.base')));
    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('return json(data, coreResponse.status);'));
    expect(edge, isNot(contains('13off.github.io/appstroy-web')));
    expect(edge, isNot(contains('publishedWebAppUrl')));
    expect(edge, isNot(contains('input.redirect_to')));
    expect(edge, isNot(contains('localhost')));
    expect(core, contains('https://api.appstroy-web.ru/app/'));
    expect(core, contains('new URL("invite.html", defaultWebAppUrl)'));
    expect(core, contains('redirect_to: invitationRedirectUrl(companyId)'));
  });
}
