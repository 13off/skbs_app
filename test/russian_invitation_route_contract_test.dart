import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation uses GitHub Pages and direct Supabase verification', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final core = source(
      'supabase/functions/invite-company-member-core/index.ts',
    );
    final landing = source('web/invite.html');
    final repository = source('lib/features/auth/data/user_repository.dart');

    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('https://13off.github.io/appstroy-web/'));
    expect(edge, contains('new URL("invite.html", publishedWebAppUrl)'));
    expect(edge, contains('result.invite_url = publicInvitationUrl'));
    expect(edge, isNot(contains('/functions/v1/invite-landing')));
    expect(edge, isNot(contains('localhost')));

    expect(core, contains('generateLink'));
    expect(core, contains('properties?.hashed_token'));

    expect(
      landing,
      contains(
        "const supabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co'",
      ),
    );
    expect(landing, contains(r"fetch(`${supabaseUrl}/auth/v1/verify`"));
    expect(
      landing,
      contains("accept.addEventListener('click', acceptInvitation)"),
    );
    expect(landing, isNot(contains('acceptInvitation();')));
    expect(landing, isNot(contains('https://api.appstroy-web.ru')));

    expect(repository, contains('https://13off.github.io/appstroy-web/'));
    expect(repository, isNot(contains('https://api.appstroy-web.ru/app/')));
  });

  test('release builds use Supabase directly and do not require a VPS', () {
    final web = source('.github/workflows/deploy-web.yml');
    final pwa = source('.github/workflows/build-pwa-release.yml');
    final android = source('.github/workflows/build-android-apk.yml');
    final ios = source('.github/workflows/build-ios-ipa.yml');

    const direct =
        '--dart-define=SUPABASE_URL=https://dxbrhsefgxcaxzmrbfrb.supabase.co';
    const proxy = '--dart-define=SUPABASE_URL=https://api.appstroy-web.ru';

    for (final workflow in [web, pwa, android, ios]) {
      expect(workflow, contains(direct));
      expect(workflow, isNot(contains(proxy)));
    }
  });
}
