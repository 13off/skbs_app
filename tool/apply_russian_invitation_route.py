from pathlib import Path

RUSSIAN_APP_URL = "https://api.appstroy-web.ru/app/"
RUSSIAN_API_URL = "https://api.appstroy-web.ru"


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Не найден ожидаемый фрагмент в {path}: {old!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


replace_once(
    "supabase/functions/invite-company-member/index.ts",
    'const defaultWebAppUrl = "https://13off.github.io/appstroy-web/";',
    f'const defaultWebAppUrl = "{RUSSIAN_APP_URL}";',
)
replace_once(
    "lib/features/auth/data/user_repository.dart",
    "      'https://13off.github.io/appstroy-web/';",
    f"      '{RUSSIAN_APP_URL}';",
)
replace_once(
    "web/invite.html",
    "      const supabaseUrl = 'https://dxbrhsefgxcaxzmrbfrb.supabase.co';",
    f"      const supabaseUrl = '{RUSSIAN_API_URL}';",
)
replace_once(
    "test/invitation_token_link_contract_test.dart",
    "    expect(edge, contains('https://13off.github.io/appstroy-web/'));",
    f"    expect(edge, contains('{RUSSIAN_APP_URL}'));",
)

Path("infra/supabase-proxy/Caddyfile").write_text(
    '''{$PROXY_DOMAIN} {
  encode zstd gzip

  @health path /proxy-health
  respond @health "ok" 200

  @appRoot path /app
  redir @appRoot /app/ 308

  handle_path /app/* {
    root * /srv/appstroy-web
    try_files {path} /index.html
    file_server
  }

  handle {
    reverse_proxy https://{$SUPABASE_UPSTREAM} {
      header_up Host {$SUPABASE_UPSTREAM}

      transport http {
        tls_server_name {$SUPABASE_UPSTREAM}
        keepalive 30s
        dial_timeout 10s
        response_header_timeout 30s
      }
    }
  }

  log {
    output stdout
    format console
  }
}
''',
    encoding="utf-8",
)

replace_once(
    "infra/supabase-proxy/docker-compose.yml",
    "      - ./Caddyfile:/etc/caddy/Caddyfile:ro\n",
    "      - ./Caddyfile:/etc/caddy/Caddyfile:ro\n"
    "      - ./site:/srv/appstroy-web:ro\n",
)
Path("infra/supabase-proxy/site").mkdir(parents=True, exist_ok=True)
Path("infra/supabase-proxy/site/.gitkeep").write_text("", encoding="utf-8")

replace_once(
    ".github/workflows/deploy-supabase-proxy.yml",
    "    paths:\n      - infra/supabase-proxy/deploy.trigger\n",
    "    paths:\n      - infra/supabase-proxy/**\n"
    "      - .github/workflows/deploy-supabase-proxy.yml\n",
)

workflow_path = Path(".github/workflows/deploy-web.yml")
workflow = workflow_path.read_text(encoding="utf-8")
workflow = workflow.replace(
    "  APP_PUBLIC_URL: https://13off.github.io/appstroy-web/",
    f"  APP_PUBLIC_URL: {RUSSIAN_APP_URL}",
    1,
)
workflow = workflow.replace(
    "            --base-href /appstroy-web/ \\",
    "            --base-href /app/ \\",
    1,
)

publish_marker = "      - name: Publish web files with conflict-safe retries\n"
if publish_marker not in workflow:
    raise RuntimeError("Не найден шаг публикации GitHub Pages")

vps_steps = r'''      - name: Publish web app to Russian VPS
        shell: bash
        env:
          VPS_HOST: ${{ secrets.VPS_HOST }}
          VPS_USER: ${{ secrets.VPS_USER }}
          VPS_SSH_KEY: ${{ secrets.VPS_SSH_KEY }}
        run: |
          for name in VPS_HOST VPS_USER VPS_SSH_KEY; do
            if [ -z "${!name}" ]; then
              echo "::error::Не найден secret $name"
              exit 1
            fi
          done

          mkdir -p ~/.ssh
          printf '%s\n' "$VPS_SSH_KEY" > ~/.ssh/appstroy_web
          chmod 600 ~/.ssh/appstroy_web
          ssh-keyscan -H "$VPS_HOST" >> ~/.ssh/known_hosts

          tar -C skbs_app/build/web -czf /tmp/appstroy-web.tar.gz .
          scp -i ~/.ssh/appstroy_web /tmp/appstroy-web.tar.gz \
            "$VPS_USER@$VPS_HOST:/tmp/appstroy-web.tar.gz"

          ssh -i ~/.ssh/appstroy_web "$VPS_USER@$VPS_HOST" 'bash -s' <<'REMOTE'
          set -euo pipefail
          SUDO=""
          if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
          fi
          $SUDO mkdir -p /opt/appstroy-proxy/site
          $SUDO find /opt/appstroy-proxy/site -mindepth 1 -maxdepth 1 -exec rm -rf {} +
          $SUDO tar -xzf /tmp/appstroy-web.tar.gz -C /opt/appstroy-proxy/site
          $SUDO rm -f /tmp/appstroy-web.tar.gz
          REMOTE

          for attempt in $(seq 1 12); do
            if curl --fail --silent --show-error \
              https://api.appstroy-web.ru/app/invite.html \
              | grep -q 'Приглашение в AppСтрой'; then
              echo "Russian web app is ready"
              break
            fi
            if [ "$attempt" -eq 12 ]; then
              echo "::error::Русская веб-версия не прошла проверку"
              exit 1
            fi
            sleep 5
          done

      - name: Prepare GitHub Pages backup
        shell: bash
        run: |
          sed -i 's#<base href="/app/">#<base href="/appstroy-web/">#' \
            skbs_app/build/web/index.html
          sed -i 's#<base href="/app/">#<base href="/appstroy-web/">#' \
            skbs_app/build/web/404.html

'''
workflow = workflow.replace(publish_marker, vps_steps + publish_marker, 1)
workflow_path.write_text(workflow, encoding="utf-8")

Path("test/russian_invitation_route_contract_test.dart").write_text(
    r'''import 'dart:io';

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
    final proxyWorkflow = source(
      '.github/workflows/deploy-supabase-proxy.yml',
    );

    expect(caddy, contains('handle_path /app/*'));
    expect(caddy, contains('root * /srv/appstroy-web'));
    expect(compose, contains('./site:/srv/appstroy-web:ro'));
    expect(webWorkflow, contains('--base-href /app/'));
    expect(webWorkflow, contains('Publish web app to Russian VPS'));
    expect(webWorkflow, contains('https://api.appstroy-web.ru/app/invite.html'));
    expect(webWorkflow, contains('Prepare GitHub Pages backup'));
    expect(proxyWorkflow, contains('- infra/supabase-proxy/**'));
  });
}
''',
    encoding="utf-8",
)
