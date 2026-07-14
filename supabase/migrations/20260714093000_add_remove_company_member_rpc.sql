create or replace function public.remove_company_member(
  p_company_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_role text;
  v_target_role text;
  v_target_email text;
  v_next_company_id uuid;
  v_next_role text;
  v_next_object_name text;
begin
  if v_actor_id is null then
    raise exception 'Требуется вход в аккаунт';
  end if;

  select membership.role
    into v_actor_role
  from public.company_memberships membership
  where membership.company_id = p_company_id
    and membership.user_id = v_actor_id
    and membership.is_active = true;

  if v_actor_role is null or v_actor_role not in ('owner', 'admin') then
    raise exception 'Удалять пользователей может только администратор компании';
  end if;

  if p_user_id = v_actor_id then
    raise exception 'Нельзя удалить самого себя';
  end if;

  select membership.role
    into v_target_role
  from public.company_memberships membership
  where membership.company_id = p_company_id
    and membership.user_id = p_user_id
  for update;

  if v_target_role is null then
    raise exception 'Пользователь уже удалён из компании';
  end if;

  if v_target_role = 'owner' then
    raise exception 'Нельзя удалить владельца компании';
  end if;

  select lower(account.email)
    into v_target_email
  from auth.users account
  where account.id = p_user_id;

  update public.company_invitations invitation
  set status = 'revoked',
      updated_at = now()
  where invitation.company_id = p_company_id
    and invitation.status = 'pending'
    and (
      invitation.invited_user_id = p_user_id
      or (
        v_target_email is not null
        and lower(invitation.email) = v_target_email
      )
    );

  delete from public.push_device_tokens token
  where token.company_id = p_company_id
    and token.user_id = p_user_id;

  delete from public.object_memberships assignment
  where assignment.company_id = p_company_id
    and assignment.user_id = p_user_id;

  delete from public.company_memberships membership
  where membership.company_id = p_company_id
    and membership.user_id = p_user_id;

  if exists (
    select 1
    from public.user_profiles profile
    where profile.id = p_user_id
      and profile.active_company_id = p_company_id
  ) then
    select membership.company_id, membership.role
      into v_next_company_id, v_next_role
    from public.company_memberships membership
    where membership.user_id = p_user_id
      and membership.is_active = true
    order by membership.created_at
    limit 1;

    if v_next_company_id is null then
      update public.user_profiles profile
      set active_company_id = null,
          role = 'foreman',
          object_name = null,
          updated_at = now()
      where profile.id = p_user_id;
    else
      if v_next_role = 'foreman' then
        select object.name
          into v_next_object_name
        from public.object_memberships assignment
        join public.objects object
          on object.company_id = assignment.company_id
         and object.id = assignment.object_id
        where assignment.company_id = v_next_company_id
          and assignment.user_id = p_user_id
        order by assignment.created_at
        limit 1;
      end if;

      update public.user_profiles profile
      set active_company_id = v_next_company_id,
          role = case when v_next_role in ('owner', 'admin') then 'admin' else 'foreman' end,
          object_name = case when v_next_role = 'foreman' then v_next_object_name else null end,
          updated_at = now()
      where profile.id = p_user_id;
    end if;
  end if;

  return jsonb_build_object(
    'removed', true,
    'company_id', p_company_id,
    'user_id', p_user_id
  );
end;
$$;

revoke all on function public.remove_company_member(uuid, uuid) from public;
revoke all on function public.remove_company_member(uuid, uuid) from anon;
grant execute on function public.remove_company_member(uuid, uuid) to authenticated;

comment on function public.remove_company_member(uuid, uuid) is
  'Removes a non-owner member from one company, revokes pending invitations and cleans company-scoped access.';
