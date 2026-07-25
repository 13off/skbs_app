# MAX-бот СКБС на VPS

Сервис принимает заявки кандидатов из MAX, передаёт их в кадровую CRM AppСтрой, доставляет исходящие сообщения HR и сохраняет незавершённые анкеты в постоянном каталоге `data`.

Фото, PDF и DOCX до 20 МБ скачиваются из MAX, загружаются в закрытый бакет `recruitment-documents` и появляются одновременно в переписке и документах кандидата. Публичные ссылки на файлы не создаются.

## Первый запуск на VPS

Требования: установлен Docker с плагином `docker compose`, каталог `/opt/appstroy-max-bot` доступен пользователю деплоя.

```bash
sudo mkdir -p /opt/appstroy-max-bot/data
sudo chown -R "$USER":"$USER" /opt/appstroy-max-bot
cd /opt/appstroy-max-bot
cp .env.example .env
nano .env
```

Обязательные значения в `.env`:

```env
BOT_TOKEN=<токен MAX-бота>
ADMIN_SETUP_CODE=<длинный секретный код>
APPSTROY_BRIDGE_URL=https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/max-recruitment-bridge
APPSTROY_FILE_BRIDGE_URL=https://dxbrhsefgxcaxzmrbfrb.supabase.co/functions/v1/max-recruitment-file-bridge
APPSTROY_BRIDGE_SECRET=<секрет моста AppСтрой>
MAX_API_BASE_URL=https://platform-api2.max.ru
MAX_INBOUND_FILE_MAX_BYTES=20971520
DEBUG=0
DATA_FILE=/app/data/bot-data.json
```

Запуск:

```bash
docker compose -f compose.yml build --pull
docker compose -f compose.yml up -d --force-recreate --remove-orphans
docker compose -f compose.yml logs -f --tail=100 max-recruiting-bot
```

После появления строки `MAX-бот запущен` локальный бот на Windows необходимо закрыть: два Long Polling-процесса с одним токеном одновременно запускать нельзя.

## Проверка

```bash
docker compose -f compose.yml ps
docker inspect --format '{{json .State.Health}}' appstroy-max-recruiting-bot
docker compose -f compose.yml logs --tail=100 max-recruiting-bot
```

## Обновление одной командой

После первого размещения сервиса следующие версии можно устанавливать без архивов:

```bash
cd /opt/appstroy-max-bot
bash update.sh
```

Скрипт сохраняет существующие `.env` и `data`, загружает актуальный код, пересобирает контейнер и выводит последние логи.

## Автоматические обновления

Workflow `.github/workflows/deploy-max-bot-vps.yml` копирует изменённые файлы на VPS и пересоздаёт контейнер. В GitHub должны быть настроены секреты:

- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_KEY`

Файл `/opt/appstroy-max-bot/.env` workflow не заменяет.

## Данные

`/opt/appstroy-max-bot/data/bot-data.json` содержит локальные сессии, зарегистрированных администраторов и резервную очередь заявок. Каталог подключён как volume и сохраняется при пересборке контейнера.
