create or replace function public.accept_current_company_invitation()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_updated_count integer := 0;
begin
  if v_user_id is null then
    raise exception 'Требуется вход в аккаунт' using errcode = '42501';
  end if;

  update public.company_invitations as invitation
  set
    status = 'accepted',
    accepted_at = coalesce(invitation.accepted_at, now()),
    updated_at = now()
  where invitation.invited_user_id = v_user_id
    and invitation.status = 'pending'
    and exists (
      select 1
      from public.user_profiles as profile
      where profile.id = v_user_id
        and profile.active_company_id = invitation.company_id
    )
    and exists (
      select 1
      from public.company_memberships as membership
      where membership.company_id = invitation.company_id
        and membership.user_id = v_user_id
        and membership.is_active
    )
    and exists (
      select 1
      from auth.users as invited_user
      where invited_user.id = v_user_id
        and coalesce(
          (invited_user.raw_user_meta_data ->> 'must_set_password')::boolean,
          false
        ) = false
    );

  get diagnostics v_updated_count = row_count;
  return v_updated_count;
end;
$function$;

revoke all on function public.accept_current_company_invitation() from public;
revoke all on function public.accept_current_company_invitation() from anon;
grant execute on function public.accept_current_company_invitation() to authenticated;
grant execute on function public.accept_current_company_invitation() to service_role;

comment on function public.accept_current_company_invitation() is
  'Marks the signed-in user invitation accepted after the required password has been set.';

