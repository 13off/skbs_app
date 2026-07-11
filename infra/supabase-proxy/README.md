# AppСтрой Supabase Proxy

Прокси разворачивается один раз на российском VPS. На телефоны и компьютеры ничего отдельно не устанавливается.

## Требования

- VPS с Ubuntu 22.04/24.04;
- публичный IPv4;
- домен или поддомен, например `api.appstroy.ru`;
- DNS A-запись домена должна указывать на IPv4 сервера;
- установленные Docker Engine и Docker Compose Plugin.

## Запуск

```bash
git clone https://github.com/13off/skbs_app.git
cd skbs_app/infra/supabase-proxy
cp .env.example .env
nano .env
docker compose up -d
```

Caddy автоматически получает и продлевает HTTPS-сертификат.

Проверка:

```bash
curl https://api.appstroy.ru/proxy-health
```

Ожидаемый ответ:

```text
ok
```

Проверка Supabase через прокси:

```bash
curl https://api.appstroy.ru/auth/v1/health
```

Ответ `No API key found in request` означает, что прокси и Supabase доступны.

## Подключение приложения

В GitHub Actions репозитория `13off/skbs_app` добавить secret:

```text
SUPABASE_PROXY_URL=https://api.appstroy.ru
```

Ключ `SUPABASE_PROXY_KEY` пока можно не добавлять: используется текущий publishable key Supabase.

После добавления секрета запустить оба workflow:

- `Build and publish web`;
- `Build Android APK`.

Новые веб-сборки и APK будут обращаться к прокси автоматически.

## Обновление

```bash
cd skbs_app/infra/supabase-proxy
git pull
docker compose pull
docker compose up -d
```
