alter table public.user_profiles drop constraint if exists user_profiles_role_check;
alter table public.user_profiles add constraint user_profiles_role_check
  check (role = any (array['admin','developer','foreman','employee','lawyer','accountant','hr','procurement']::text[]));

alter table public.company_memberships drop constraint if exists company_memberships_role_check;
alter table public.company_memberships add constraint company_memberships_role_check
  check (role = any (array['owner','admin','developer','foreman','lawyer','accountant','hr','procurement']::text[]));

alter table public.company_invitations drop constraint if exists company_invitations_role_check;
alter table public.company_invitations add constraint company_invitations_role_check
  check (role = any (array['admin','developer','foreman','lawyer','accountant','hr','procurement']::text[]));

alter table public.role_permissions drop constraint if exists role_permissions_role_check;
alter table public.role_permissions add constraint role_permissions_role_check
  check (role_code = any (array['owner','admin','developer','foreman','lawyer','accountant','hr','procurement']::text[]));

alter table public.app_notifications drop constraint if exists app_notifications_source_role_check;
alter table public.app_notifications add constraint app_notifications_source_role_check
  check (source_role = any (array['admin','foreman','hr','accountant','lawyer','procurement']::text[]));

alter table public.app_notifications drop constraint if exists app_notifications_target_role_check;
alter table public.app_notifications add constraint app_notifications_target_role_check
  check (target_role is null or target_role = any (array['admin','foreman','lawyer','accountant','hr','procurement']::text[]));

alter table public.notification_role_preferences drop constraint if exists notification_role_preferences_roles_check;
alter table public.notification_role_preferences add constraint notification_role_preferences_roles_check
  check (selected_roles <@ array['admin','foreman','hr','accountant','lawyer','procurement']::text[]);

alter table public.notification_role_preferences drop constraint if exists notification_role_preferences_bell_roles_check;
alter table public.notification_role_preferences add constraint notification_role_preferences_bell_roles_check
  check (selected_bell_roles <@ array['admin','foreman','hr','accountant','lawyer','procurement']::text[]);

insert into public.permission_catalog(
  permission_code, category, title, description, supports_object_scope, sort_order
) values
  ('procurement.requests.view','Снабжение','Просмотр заявок','Просмотр заявок на материалы и оборудование.',true,610),
  ('procurement.requests.create','Снабжение','Создание заявок','Создание заявок на снабжение.',true,611),
  ('procurement.requests.edit','Снабжение','Работа с заявками','Редактирование состава, поставщика, суммы и сроков.',true,612),
  ('procurement.requests.approve','Снабжение','Согласование заявок','Перевод заявки в согласованный статус.',false,613),
  ('procurement.suppliers.view','Снабжение','Просмотр поставщиков','Доступ к справочнику поставщиков.',false,614),
  ('procurement.suppliers.edit','Снабжение','Управление поставщиками','Создание и изменение поставщиков.',false,615),
  ('procurement.delivery.edit','Снабжение','Управление доставкой','Заказ, доставка и приёмка материалов.',true,616),
  ('procurement.reports.view','Снабжение','Сводка снабжения','Просмотр сумм, сроков и состояния закупок.',false,617)
on conflict (permission_code) do update set
  category=excluded.category,
  title=excluded.title,
  description=excluded.description,
  supports_object_scope=excluded.supports_object_scope,
  sort_order=excluded.sort_order,
  updated_at=now();

insert into public.role_permissions(role_code, permission_code)
select role_code, permission_code
from (values
  ('procurement','procurement.requests.view'),
  ('procurement','procurement.requests.create'),
  ('procurement','procurement.requests.edit'),
  ('procurement','procurement.requests.approve'),
  ('procurement','procurement.suppliers.view'),
  ('procurement','procurement.suppliers.edit'),
  ('procurement','procurement.delivery.edit'),
  ('procurement','procurement.reports.view'),
  ('procurement','objects.view'),
  ('procurement','company_chat.view'),
  ('procurement','company_chat.send'),
  ('procurement','company_chat.files'),
  ('procurement','notifications.center.view'),
  ('foreman','procurement.requests.view'),
  ('foreman','procurement.requests.create'),
  ('accountant','procurement.requests.view'),
  ('accountant','procurement.reports.view')
) as defaults(role_code, permission_code)
on conflict do nothing;

insert into public.role_permissions(role_code, permission_code)
select role_code, permission.permission_code
from (values ('owner'),('admin'),('developer')) as roles(role_code)
cross join (values
  ('procurement.requests.view'),
  ('procurement.requests.create'),
  ('procurement.requests.edit'),
  ('procurement.requests.approve'),
  ('procurement.suppliers.view'),
  ('procurement.suppliers.edit'),
  ('procurement.delivery.edit'),
  ('procurement.reports.view')
) as permission(permission_code)
on conflict do nothing;
