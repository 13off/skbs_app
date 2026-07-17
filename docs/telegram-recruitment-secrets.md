# Telegram-секреты для подбора персонала

Секреты нельзя хранить во Flutter-клиенте, GitHub или миграциях базы.

## 1. Обновить токен бота

В BotFather перевыпустить токен бота `@skbs_work_bot`, если прежний токен когда-либо передавался в открытом сообщении.

## 2. Добавить Supabase Edge Function Secrets

В Supabase Dashboard открыть:

`Project Settings → Edge Functions → Secrets`

Добавить:

- `TELEGRAM_RECRUITMENT_BOT_TOKEN` — новый токен BotFather;
- `TELEGRAM_WEBHOOK_SECRET` — новая случайная строка минимум 32 символа.

Значения не коммитить и не вставлять в клиентское приложение.

## 3. Серверные функции

После добавления секретов повторно развернуть:

- `telegram-recruitment-bot`;
- `recruitment-candidate-action`;
- `recruitment-ingest-telegram-file`.

## 4. Повторная загрузка старых файлов

Старые строки с `telegram://...` нужно повторно поставить в очередь загрузки. Новые документы обрабатываются автоматически триггером `recruitment_documents_ingest_telegram_file`.

## 5. Проверка

1. Кандидат отправляет тестовое изображение боту.
2. В `recruitment_documents.storage_bucket` появляется `recruitment-documents`.
3. `storage_path` имеет вид `company_id/application_id/document_type/file.ext`.
4. HR открывает документ по временной подписанной ссылке.
5. HR отправляет сообщение из карточки кандидата и получает его в Telegram.
