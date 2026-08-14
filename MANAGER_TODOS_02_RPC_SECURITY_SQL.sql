-- AppСтрой: manager todos RPCs are only callable by signed-in users.
-- The functions themselves additionally require the current user to be an admin.

revoke execute on function public.get_my_manager_todos(boolean, integer) from anon;
revoke execute on function public.create_manager_todo(text, text, timestamptz) from anon;
revoke execute on function public.set_manager_todo_done(uuid, boolean) from anon;
