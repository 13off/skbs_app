-- Keep team directories admin-only and cover every new foreign key used by
-- invitation, switching and billing queries.

drop policy if exists company_memberships_select_members
on public.company_memberships;
create policy company_memberships_select_own_or_admin
on public.company_memberships for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_company_admin(company_id))
);

drop policy if exists object_memberships_select_members
on public.object_memberships;
create policy object_memberships_select_own_or_admin
on public.object_memberships for select to authenticated
using (
  user_id = (select auth.uid())
  or (select public.is_company_admin(company_id))
);

create index if not exists companies_owner_user_id_idx
  on public.companies(owner_user_id);
create index if not exists company_invitations_invited_by_idx
  on public.company_invitations(invited_by);
create index if not exists company_invitations_invited_user_id_idx
  on public.company_invitations(invited_user_id);
create index if not exists company_invitations_company_object_idx
  on public.company_invitations(company_id, object_id);
create index if not exists company_memberships_invited_by_idx
  on public.company_memberships(invited_by);
create index if not exists object_memberships_created_by_idx
  on public.object_memberships(created_by);
create index if not exists user_profiles_active_company_id_idx
  on public.user_profiles(active_company_id);

