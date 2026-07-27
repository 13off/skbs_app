import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation uses the canonical landing and Russian API', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final core = source(
      'supabase/functions/invite-company-member-core/index.ts',
    );
    final landing = source('web/invite.html');

    expect(edge, contains('invite-company-member-core'));
    expect(edge, contains('return json(data, coreResponse.status);'));
    expect(edge, isNot(contains('13off.github.io/appstroy-web')));
    expect(edge, isNot(contains('publishedWebAppUrl')));
    expect(edge, isNot(contains('/functions/v1/invite-landing')));
    expect(edge, isNot(contains('localhost')));
    expect(core, contains('https://api.appstroy-web.ru/app/'));
    expect(core, contains('new URL("invite.html", defaultWebAppUrl)'));

    expect(
      landing,
      contains("const supabaseUrl = 'https://api.appstroy-web.ru'"),
    );
    expect(
      landing,
      contains(r"fetch(`${supabaseUrl}/auth/v1/verify`"),
    );
    expect(
      landing,
      contains("accept.addEventListener('click', acceptInvitation)"),
    );
    expect(landing, isNot(contains('acceptInvitation();')));
  });

  test('Russian proxy still forwards Auth and REST requests', () {
    final caddy = source('infra/supabase-proxy/Caddyfile');
    final compose = source('infra/supabase-proxy/docker-compose.yml');
    final landing = source('web/invite.html');

    expect(caddy, contains('reverse_proxy https://'));
    expect(caddy, contains(r'{$SUPABASE_UPSTREAM}'));
    expect(compose, contains('SUPABASE_UPSTREAM:'));
    expect(landing, contains('/auth/v1/verify'));
  });
}
