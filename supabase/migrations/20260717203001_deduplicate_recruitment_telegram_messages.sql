create unique index if not exists recruitment_messages_telegram_delivery_unique
  on public.recruitment_messages (application_id, direction, telegram_message_id)
  where telegram_message_id is not null;
