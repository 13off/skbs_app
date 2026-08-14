# Безопасность Edge Functions

Этот файл фиксирует обязательные настройки для функций, у которых изменён контракт безопасности. Секреты не хранятся в Git, Flutter-клиенте или SQL-миграциях.

## Режим проверки JWT

| Функция | `verify_jwt` | Дополнительная защита |
| --- | --- | --- |
| `openai-smoke-test` | `true` | `auth.getUser()`, активная компания, роль `owner` / `admin` / `developer` |
| `test-google-drive-download` | `true` | Заглушка `410 Gone`; функцию следует удалить после безопасного деплоя |
| `request-employee-otp` | `false` | Ограничение частоты по IP и телефону, одинаковый ответ для существующего и отсутствующего номера |
| `site-recruitment-application` | `false` | Cloudflare Turnstile, allowlist Origin и ограничение частоты по IP и телефону |
| `recruitment-ingest-telegram-file` | `false` | Заголовок `x-recruitment-ingest-secret`, сравнение по SHA-256, проверка типа и размера файла |
| `assistant-payment-receipts` | `false` | Заголовок `x-assistant-secret`, сравнение по SHA-256, ограничение размера и magic bytes |
| `upload-recruitment-archive` | `false` | Одноразовый токен загрузки, атомарный claim, лимиты ZIP и проверка SHA-256 каждого файла |
| `dispatch-push-job` | `false` | Одноразовый `dispatch_token` задания и атомарный lease (`lease_token`) |

Все остальные пользовательские функции должны оставаться с `verify_jwt=true`, если их публичный или служебный контракт отдельно не описан и не защищён.

## Обязательные секреты

- `EDGE_RATE_LIMIT_PEPPER` — случайная строка не короче 32 байт для необратимого хеширования идентификаторов rate limit.
- `SITE_RECRUITMENT_TURNSTILE_SECRET` — secret key Cloudflare Turnstile.
- `SITE_RECRUITMENT_TURNSTILE_SITE_KEY` — публичный site key; landing получает его через защищённый по Origin `GET` той же функции.
- `SITE_RECRUITMENT_ALLOWED_ORIGINS` — дополнительные разрешённые origin через запятую; базовые production-домены уже перечислены в коде.
- `RECRUITMENT_INGEST_SECRET_SHA256` — SHA-256 от значения Vault-секрета `recruitment_ingest_secret`.
- `ASSISTANT_PAYMENT_RECEIPTS_SECRET_SHA256` — SHA-256 от значения Vault-секрета `assistant_payment_receipt_secret`.
- `TELEGRAM_RECRUITMENT_BOT_TOKEN` — токен Telegram-бота для скачивания файлов.
- `FIREBASE_SERVICE_ACCOUNT_JSON` — сервисная учётная запись для push.
- `OPENAI_API_KEY` и, при необходимости, `OPENAI_MODEL` — только для функций OpenAI.

Пример получения SHA-256 без передачи секрета в аргументах процесса:

```powershell
$secretValue = Read-Host -AsSecureString
$plainValue = [System.Net.NetworkCredential]::new('', $secretValue).Password
$bytes = [System.Text.Encoding]::UTF8.GetBytes($plainValue)
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
$plainValue = $null
$hash
```

## Порядок включения защиты

1. Создать случайные значения `recruitment_ingest_secret` и `assistant_payment_receipt_secret` в Supabase Vault.
2. Добавить соответствующие SHA-256 значения в Edge Function Secrets.
3. Настроить Turnstile на production-доменах и добавить secret key.
4. Обновить landing-форму так, чтобы она передавала `turnstileToken`.
5. Применить миграции базы.
6. Развернуть функции с режимом `verify_jwt` из таблицы выше.
7. Проверить положительный запрос и отказ без JWT, секрета, Turnstile или одноразового токена — в зависимости от функции.

Не разворачивать `site-recruitment-application` до обновления landing-формы и настройки Turnstile: функция намеренно работает по принципу fail closed.
