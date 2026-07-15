import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation stays on the Russian Edge and API route', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final landing = source('supabase/functions/invite-landing/index.ts');

    expect(
      edge,
      contains(
        'https://api.appstroy-web.ru/functions/v1/invite-landing',
      ),
    );
    expect(edge, isNot(contains('github.io')));
    expect(edge, isNot(contains('/app/invite.html')));
    expect(landing, contains('const apiBase = window.location.origin'));
    expect(landing, contains("api('/auth/v1/verify'"));
    expect(landing, isNot(contains('.supabase.co')));
    expect(landing, isNot(contains('github.io')));
  });

  test('existing Russian proxy already forwards the Edge Function route', () {
    final caddy = source('infra/supabase-proxy/Caddyfile');
    final compose = source('infra/supabase-proxy/docker-compose.yml');
    final landing = source('supabase/functions/invite-landing/index.ts');

    expect(caddy, contains('reverse_proxy https://'));
    expect(caddy, contains(r'{$SUPABASE_UPSTREAM}'));
    expect(compose, contains('SUPABASE_UPSTREAM:'));
    expect(landing, contains('Deno.serve'));
    expect(landing, contains('SUPABASE_ANON_KEY'));
  });
}
