revoke all on function public.can_view_company_chat_thread(uuid, text, uuid, uuid) from anon;
revoke all on function public.get_company_chat_threads() from anon;
revoke all on function public.get_company_chat_feed(integer, timestamptz, text, uuid) from anon;
revoke all on function public.create_company_chat_message(text, uuid, uuid[], text, text, uuid) from anon;
revoke all on function public.mark_company_chat_read(timestamptz, text, uuid) from anon;
revoke all on function public.get_company_chat_unread_state() from anon;
revoke all on function public.delete_company_chat_message(uuid) from anon;

-- Исправляет права функции удаления колонок CRM, созданной предыдущей миграцией.
revoke all on function public.delete_recruitment_pipeline_stage(uuid, uuid) from anon;
