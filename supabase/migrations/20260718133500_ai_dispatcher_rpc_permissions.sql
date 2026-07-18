revoke all on function public.get_dispatcher_summary_center()
  from public, anon;
revoke all on function public.save_dispatcher_summary_settings(jsonb)
  from public, anon;
revoke all on function public.run_dispatcher_summary_now()
  from public, anon;

grant execute on function public.get_dispatcher_summary_center()
  to authenticated;
grant execute on function public.save_dispatcher_summary_settings(jsonb)
  to authenticated;
grant execute on function public.run_dispatcher_summary_now()
  to authenticated;
