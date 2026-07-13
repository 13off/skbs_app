drop policy if exists "service role manages push deliveries"
  on public.push_notification_deliveries;

create policy "service role manages push deliveries"
  on public.push_notification_deliveries
  for all
  to service_role
  using (true)
  with check (true);
