import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('invitation stays on the Russian web and API route', () {
    final edge = source('supabase/functions/invite-company-member/index.ts');
    final repository = source('lib/features/auth/data/user_repository.dart');
    final invitePage = source('web/invite.html');

    expect(edge, contains('https://api.appstroy-web.ru/app/'));
    expect(repository, contains('https://api.appstroy-web.ru/app/'));
    expect(invitePage, contains("https://api.appstroy-web.ru"));
    expect(invitePage, isNot(contains('.supabase.co')));
    expect(edge, isNot(contains('github.io')));
  });

  test('Russian VPS serves the app while GitHub remains a backup', () {
    final caddy = source('infra/supabase-proxy/Caddyfile');
    final compose = source('infra/supabase-proxy/docker-compose.yml');
    final webWorkflow = source('.github/workflows/deploy-web.yml');
    final proxyWorkflow = source('.github/workflows/deploy-supabase-proxy.yml');

    expect(caddy, contains('handle_path /app/*'));
    expect(caddy, contains('root * /srv/appstroy-web'));
    expect(compose, contains('./site:/srv/appstroy-web:ro'));
    expect(webWorkflow, contains('--base-href /app/'));
    expect(webWorkflow, contains('Publish web app to Russian VPS'));
    expect(
      webWorkflow,
      contains('https://api.appstroy-web.ru/app/invite.html'),
    );
    expect(webWorkflow, contains('Prepare GitHub Pages backup'));
    expect(proxyWorkflow, contains('- infra/supabase-proxy/**'));
  });
}
