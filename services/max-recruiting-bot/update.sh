#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/opt/appstroy-max-bot"
REPOSITORY_URL="https://github.com/13off/skbs_app.git"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "Не найден $ROOT_DIR/.env" >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "Не установлен git" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Не установлен docker" >&2; exit 1; }

echo "Загружаю актуальную версию MAX-бота..."
git clone --depth 1 "$REPOSITORY_URL" "$TEMP_DIR/skbs_app"

mkdir -p "$ROOT_DIR/data"
cp -a "$TEMP_DIR/skbs_app/services/max-recruiting-bot/." "$ROOT_DIR/"
chmod 600 "$ROOT_DIR/.env"
chown -R 1000:1000 "$ROOT_DIR/data"

cd "$ROOT_DIR"
echo "Проверяю и пересобираю контейнер..."
docker compose -f compose.yml build --pull
docker compose -f compose.yml up -d --force-recreate --remove-orphans

echo
docker compose -f compose.yml ps
echo
docker compose -f compose.yml logs --tail=100 max-recruiting-bot
