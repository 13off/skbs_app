# Нормализация версий SQL-миграций

Повторяющиеся версии заменены ближайшими свободными секундами.
Содержимое SQL не изменялось.

Перед production deploy нужно сверить `supabase_migrations.schema_migrations`
и при необходимости выполнить штатный `supabase migration repair`.

## Переименования

- `20260717203000_deduplicate_recruitment_telegram_messages.sql` → `20260717203001_deduplicate_recruitment_telegram_messages.sql`
- `20260718150000_notification_control_center.sql` → `20260718150001_notification_control_center.sql`
