create table if not exists public.permission_catalog (
  permission_code text primary key,
  category text not null,
  title text not null,
  description text not null default '',
  supports_object_scope boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.company_role_permission_overrides (
  company_id uuid not null references public.companies(id) on delete cascade,
  role_code text not null,
  permission_code text not null references public.permission_catalog(permission_code) on delete cascade,
  is_allowed boolean not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (company_id, role_code, permission_code)
);

create table if not exists public.object_role_permission_overrides (
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid not null references public.objects(id) on delete cascade,
  role_code text not null,
  permission_code text not null references public.permission_catalog(permission_code) on delete cascade,
  is_allowed boolean not null,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (company_id, object_id, role_code, permission_code)
);

create table if not exists public.role_permission_audit (
  id bigint generated always as identity primary key,
  company_id uuid not null references public.companies(id) on delete cascade,
  object_id uuid references public.objects(id) on delete set null,
  scope text not null check (scope in ('company','object')),
  role_code text not null,
  permission_code text not null,
  action text not null check (action in ('set','reset')),
  before_allowed boolean,
  after_allowed boolean not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_name text not null default '',
  created_at timestamptz not null default now()
);

alter table public.permission_catalog enable row level security;
alter table public.company_role_permission_overrides enable row level security;
alter table public.object_role_permission_overrides enable row level security;
alter table public.role_permission_audit enable row level security;

revoke all on public.permission_catalog from anon, authenticated;
revoke all on public.company_role_permission_overrides from anon, authenticated;
revoke all on public.object_role_permission_overrides from anon, authenticated;
revoke all on public.role_permission_audit from anon, authenticated;

create index if not exists company_role_permission_overrides_company_idx
  on public.company_role_permission_overrides(company_id, role_code);
create index if not exists object_role_permission_overrides_object_idx
  on public.object_role_permission_overrides(company_id, object_id, role_code);
create index if not exists role_permission_audit_company_created_idx
  on public.role_permission_audit(company_id, created_at desc);
create index if not exists role_permission_audit_actor_idx
  on public.role_permission_audit(actor_user_id);

insert into public.permission_catalog(
  permission_code, category, title, description, supports_object_scope, sort_order
)
select distinct
  permission_code,
  case split_part(permission_code, '.', 1)
    when 'accounting' then 'Бухгалтерия'
    when 'recruitment' then 'Подбор'
    when 'legal' then 'Юридический блок'
    when 'personal_data' then 'Персональные данные'
    else 'Прочее'
  end,
  permission_code,
  'Существующее системное право',
  permission_code in (
    'accounting.payments.view', 'accounting.payments.edit',
    'accounting.receipts.view', 'accounting.receipts.edit'
  ),
  2000
from public.role_permissions
on conflict (permission_code) do nothing;

insert into public.permission_catalog
(permission_code, category, title, description, supports_object_scope, sort_order)
values
('tasks.view','Задачи','Просмотр задач','Открывать задачи доступных объектов.',true,10),
('tasks.create','Задачи','Создание задач','Создавать и публиковать задачи.',true,20),
('tasks.edit','Задачи','Редактирование задач','Менять задачу в рамках ограничений объекта.',true,30),
('tasks.delete','Задачи','Удаление задач','Перемещать задачи в корзину.',true,40),
('tasks.assignees.manage','Задачи','Исполнители задач','Добавлять и удалять исполнителей.',true,50),
('tasks.photos.manage','Задачи','Фотографии задач','Добавлять и удалять фотографии.',true,60),
('attendance.view','Табель','Просмотр табеля','Просматривать табель доступных объектов.',true,110),
('attendance.edit','Табель','Редактирование табеля','Заполнять и изменять смены и часы.',true,120),
('attendance.delete','Табель','Удаление записей табеля','Удалять ошибочные записи табеля.',true,130),
('employees.view','Сотрудники','Просмотр сотрудников','Просматривать сотрудников доступных объектов.',true,210),
('employees.create','Сотрудники','Добавление сотрудников','Создавать карточки сотрудников.',true,220),
('employees.edit','Сотрудники','Редактирование сотрудников','Изменять данные и назначение на объект.',true,230),
('employees.archive','Сотрудники','Архив сотрудников','Перемещать сотрудников в архив и возвращать.',true,240),
('employees.delete','Сотрудники','Безвозвратное удаление сотрудников','Удалять архивные карточки после подтверждения.',true,250),
('objects.view','Объекты','Просмотр объектов','Открывать назначенные и разрешённые объекты.',true,310),
('objects.create','Объекты','Создание объектов','Добавлять новые объекты компании.',false,320),
('objects.edit','Объекты','Редактирование объектов','Менять данные объекта.',true,330),
('objects.archive','Объекты','Архив объектов','Архивировать и восстанавливать объекты.',true,340),
('objects.delete','Объекты','Безвозвратное удаление объектов','Удалять архивные объекты после проверки связей.',true,350),
('goals.view','Цели и этапы','Просмотр целей','Просматривать цели, этапы и контрольные пункты.',true,410),
('goals.edit','Цели и этапы','Редактирование целей','Создавать и изменять цели и этапы.',true,420),
('goals.delete','Цели и этапы','Удаление целей','Удалять цели, этапы и пункты.',true,430),
('documents.templates.view','Документы','Просмотр шаблонов','Открывать системные и корпоративные шаблоны.',false,510),
('documents.templates.edit','Документы','Редактирование шаблонов','Добавлять версии и изменять шаблоны.',false,520),
('notifications.center.view','Уведомления','Центр уведомлений','Открывать центр уведомлений и напоминаний.',false,610),
('notifications.settings.manage','Уведомления','Настройки уведомлений','Менять правила доставки, роли и события.',false,620),
('notifications.create','Уведомления','Создание уведомлений','Создавать операционные уведомления.',true,630),
('ai.use','ИИ','Использование ИИ-помощника','Открывать чат и выполнять read-only запросы.',false,710),
('ai.actions.execute','ИИ','Подтверждение действий ИИ','Подтверждать изменения, подготовленные ИИ.',true,720),
('reports.view','Отчёты','Просмотр отчётов','Открывать сводки и отчёты.',true,810),
('reports.export','Отчёты','Экспорт отчётов','Формировать и выгружать отчёты.',true,820),
('system.roles.manage','Система','Матрица ролей','Изменять права ролей компании и объектов.',false,910),
('system.audit.view','Система','Общий журнал действий','Просматривать аудит поддерживаемых сущностей.',false,920),
('system.recycle_bin.manage','Система','Корзина и восстановление','Восстанавливать и окончательно удалять записи.',false,930),
('system.settings.manage','Система','Настройки модулей','Включать модули и менять системные настройки.',false,940),
('accounting.attendance.view','Бухгалтерия','Табель для бухгалтерии','Просматривать табель всех объектов для расчётов.',false,1010),
('accounting.directory.view','Бухгалтерия','Справочник сотрудников','Просматривать справочник сотрудников для начислений.',false,1020),
('accounting.payments.view','Бухгалтерия','Просмотр выплат','Просматривать выплаты и остатки.',true,1030),
('accounting.payments.edit','Бухгалтерия','Редактирование выплат','Создавать и изменять выплаты.',true,1040),
('accounting.receipts.view','Бухгалтерия','Просмотр чеков','Просматривать подтверждающие документы.',true,1050),
('accounting.receipts.edit','Бухгалтерия','Редактирование чеков','Добавлять и удалять подтверждающие документы.',true,1060),
('accounting.reports.export','Бухгалтерия','Экспорт бухгалтерских отчётов','Выгружать расчётные отчёты.',false,1070)
on conflict (permission_code) do update set
  category = excluded.category,
  title = excluded.title,
  description = excluded.description,
  supports_object_scope = excluded.supports_object_scope,
  sort_order = excluded.sort_order,
  updated_at = now();

insert into public.role_permissions(role_code, permission_code)
select role_code, permission_code
from (values ('owner'),('admin'),('developer')) roles(role_code)
cross join public.permission_catalog
on conflict do nothing;

insert into public.role_permissions(role_code, permission_code)
values
('foreman','tasks.view'),('foreman','tasks.create'),('foreman','tasks.edit'),
('foreman','tasks.delete'),('foreman','tasks.assignees.manage'),
('foreman','tasks.photos.manage'),('foreman','attendance.view'),
('foreman','attendance.edit'),('foreman','employees.view'),
('foreman','objects.view'),('foreman','goals.view'),('foreman','goals.edit'),
('foreman','goals.delete'),('foreman','notifications.center.view'),
('foreman','notifications.create'),('foreman','ai.use'),('foreman','reports.view'),
('accountant','objects.view'),('accountant','employees.view'),
('accountant','notifications.center.view'),('accountant','reports.view'),
('accountant','reports.export'),
('hr','employees.view'),('hr','documents.templates.view'),
('hr','documents.templates.edit'),('hr','notifications.center.view'),
('hr','ai.use'),('hr','reports.view'),
('lawyer','objects.view'),('lawyer','notifications.center.view'),
('lawyer','reports.view')
on conflict do nothing;

create or replace function public.role_permission_effective(
  p_company_id uuid,
  p_object_id uuid,
  p_role_code text,
  p_permission_code text
)
returns boolean
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_allowed boolean;
begin
  if p_company_id is null
     or nullif(btrim(p_role_code), '') is null
     or nullif(btrim(p_permission_code), '') is null then
    return false;
  end if;

  if p_role_code = 'owner' then
    return true;
  end if;

  if p_object_id is not null then
    select item.is_allowed into v_allowed
      from public.object_role_permission_overrides item
     where item.company_id = p_company_id
       and item.object_id = p_object_id
       and item.role_code = p_role_code
       and item.permission_code = p_permission_code;
    if found then return v_allowed; end if;
  end if;

  select item.is_allowed into v_allowed
    from public.company_role_permission_overrides item
   where item.company_id = p_company_id
     and item.role_code = p_role_code
     and item.permission_code = p_permission_code;
  if found then return v_allowed; end if;

  return exists (
    select 1 from public.role_permissions item
     where item.role_code = p_role_code
       and item.permission_code = p_permission_code
  );
end;
$$;

create or replace function public.current_user_has_permission(p_permission_code text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.company_memberships membership
      join public.companies company on company.id = membership.company_id
     where membership.user_id = (select auth.uid())
       and membership.company_id = public.current_user_company_id()
       and membership.is_active = true
       and company.status = 'active'
       and public.role_permission_effective(
         membership.company_id, null, membership.role, p_permission_code
       )
  );
$$;

create or replace function public.current_user_has_object_permission(
  p_permission_code text,
  p_object_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.company_memberships membership
      join public.companies company on company.id = membership.company_id
      left join public.objects object_row
        on object_row.id = p_object_id
       and object_row.company_id = membership.company_id
     where membership.user_id = (select auth.uid())
       and membership.company_id = public.current_user_company_id()
       and membership.is_active = true
       and company.status = 'active'
       and (p_object_id is null or object_row.id is not null)
       and public.role_permission_effective(
         membership.company_id, p_object_id, membership.role, p_permission_code
       )
  );
$$;

create or replace function public.current_user_has_object_permission_by_name(
  p_permission_code text,
  p_object_name text
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.objects object_row
     where object_row.company_id = public.current_user_company_id()
       and lower(btrim(object_row.name)) = lower(btrim(coalesce(p_object_name, '')))
       and public.current_user_has_object_permission(p_permission_code, object_row.id)
  );
$$;

create or replace function public.current_user_has_task_permission(
  p_permission_code text,
  p_task_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.tasks task_row
     where task_row.id = p_task_id
       and task_row.company_id = public.current_user_company_id()
       and (
         (task_row.object_id is not null and public.current_user_has_object_permission(
           p_permission_code, task_row.object_id
         ))
         or
         (task_row.object_id is null and public.current_user_has_object_permission_by_name(
           p_permission_code, task_row.object_name
         ))
       )
  );
$$;

create or replace function public.current_user_has_payment_permission(
  p_permission_code text,
  p_payment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.payments payment_row
     where payment_row.id = p_payment_id
       and payment_row.company_id = public.current_user_company_id()
       and public.current_user_has_object_permission(
         p_permission_code, payment_row.object_id
       )
  );
$$;

create or replace function public.can_manage_role_permissions()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
      from public.company_memberships membership
      join public.companies company on company.id = membership.company_id
     where membership.user_id = (select auth.uid())
       and membership.company_id = public.current_user_company_id()
       and membership.is_active = true
       and company.status = 'active'
       and membership.role in ('owner','developer','admin')
  );
$$;

create or replace function public.get_role_permission_center()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_role text := public.current_user_role();
begin
  if v_company_id is null or not public.can_manage_role_permissions() then
    raise exception 'Недостаточно прав для управления матрицей ролей';
  end if;

  return jsonb_build_object(
    'actor_role', v_role,
    'roles', jsonb_build_array(
      jsonb_build_object('code','owner','title','Владелец'),
      jsonb_build_object('code','admin','title','Администратор'),
      jsonb_build_object('code','developer','title','Разработчик'),
      jsonb_build_object('code','foreman','title','Прораб'),
      jsonb_build_object('code','hr','title','HR-менеджер'),
      jsonb_build_object('code','accountant','title','Бухгалтер'),
      jsonb_build_object('code','lawyer','title','Юрист')
    ),
    'permissions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'code', item.permission_code,
        'category', item.category,
        'title', item.title,
        'description', item.description,
        'supports_object_scope', item.supports_object_scope,
        'sort_order', item.sort_order
      ) order by item.sort_order, item.permission_code)
      from public.permission_catalog item
    ), '[]'::jsonb),
    'defaults', coalesce((
      select jsonb_agg(jsonb_build_object(
        'role_code', item.role_code,
        'permission_code', item.permission_code
      ))
      from public.role_permissions item
      where item.role_code in ('owner','admin','developer','foreman','hr','accountant','lawyer')
    ), '[]'::jsonb),
    'company_overrides', coalesce((
      select jsonb_agg(jsonb_build_object(
        'role_code', item.role_code,
        'permission_code', item.permission_code,
        'is_allowed', item.is_allowed,
        'updated_at', item.updated_at
      ))
      from public.company_role_permission_overrides item
      where item.company_id = v_company_id
    ), '[]'::jsonb),
    'objects', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'name', item.name,
        'is_active', item.is_active
      ) order by item.is_active desc, lower(item.name))
      from public.objects item
      where item.company_id = v_company_id
    ), '[]'::jsonb),
    'object_overrides', coalesce((
      select jsonb_agg(jsonb_build_object(
        'object_id', item.object_id,
        'role_code', item.role_code,
        'permission_code', item.permission_code,
        'is_allowed', item.is_allowed,
        'updated_at', item.updated_at
      ))
      from public.object_role_permission_overrides item
      where item.company_id = v_company_id
    ), '[]'::jsonb),
    'audit', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'object_id', item.object_id,
        'scope', item.scope,
        'role_code', item.role_code,
        'permission_code', item.permission_code,
        'action', item.action,
        'before_allowed', item.before_allowed,
        'after_allowed', item.after_allowed,
        'actor_name', item.actor_name,
        'created_at', item.created_at
      ) order by item.created_at desc)
      from (
        select * from public.role_permission_audit
         where company_id = v_company_id
         order by created_at desc
         limit 80
      ) item
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.save_role_permission_override(
  p_scope text,
  p_role_code text,
  p_permission_code text,
  p_is_allowed boolean,
  p_object_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_actor_role text := public.current_user_role();
  v_before boolean;
  v_actor_name text := '';
  v_supports_object boolean := false;
begin
  if v_company_id is null or not public.can_manage_role_permissions() then
    raise exception 'Недостаточно прав для управления матрицей ролей';
  end if;
  if p_scope not in ('company','object') then
    raise exception 'Неизвестная область настройки';
  end if;
  if p_role_code not in ('admin','developer','foreman','hr','accountant','lawyer') then
    raise exception 'Эту роль нельзя изменять';
  end if;
  if v_actor_role = 'admin' and p_role_code in ('admin','developer') then
    raise exception 'Администратор не может изменять системные роли';
  end if;
  if p_role_code = 'developer'
     and p_permission_code in ('system.roles.manage','system.settings.manage')
     and p_is_allowed = false then
    raise exception 'Нельзя отключить разработчику доступ к системной платформе';
  end if;

  select item.supports_object_scope into v_supports_object
    from public.permission_catalog item
   where item.permission_code = p_permission_code;
  if not found then raise exception 'Неизвестное право'; end if;

  if p_scope = 'object' then
    if not v_supports_object then
      raise exception 'Это право настраивается только для всей компании';
    end if;
    if p_object_id is null or not exists (
      select 1 from public.objects item
       where item.id = p_object_id and item.company_id = v_company_id
    ) then
      raise exception 'Объект не найден';
    end if;
  else
    p_object_id := null;
  end if;

  v_before := public.role_permission_effective(
    v_company_id,
    case when p_scope = 'object' then p_object_id else null end,
    p_role_code,
    p_permission_code
  );

  if p_scope = 'company' then
    insert into public.company_role_permission_overrides(
      company_id, role_code, permission_code, is_allowed, updated_by, updated_at
    ) values (
      v_company_id, p_role_code, p_permission_code, p_is_allowed, auth.uid(), now()
    )
    on conflict (company_id, role_code, permission_code)
    do update set is_allowed = excluded.is_allowed,
                  updated_by = excluded.updated_by,
                  updated_at = excluded.updated_at;
  else
    insert into public.object_role_permission_overrides(
      company_id, object_id, role_code, permission_code,
      is_allowed, updated_by, updated_at
    ) values (
      v_company_id, p_object_id, p_role_code, p_permission_code,
      p_is_allowed, auth.uid(), now()
    )
    on conflict (company_id, object_id, role_code, permission_code)
    do update set is_allowed = excluded.is_allowed,
                  updated_by = excluded.updated_by,
                  updated_at = excluded.updated_at;
  end if;

  select coalesce(
    nullif(btrim(item.full_name), ''),
    nullif(btrim(item.email), ''),
    'Пользователь'
  ) into v_actor_name
  from public.user_profiles item
  where item.id = auth.uid();

  insert into public.role_permission_audit(
    company_id, object_id, scope, role_code, permission_code,
    action, before_allowed, after_allowed, actor_user_id, actor_name
  ) values (
    v_company_id, p_object_id, p_scope, p_role_code, p_permission_code,
    'set', v_before, p_is_allowed, auth.uid(), coalesce(v_actor_name, 'Пользователь')
  );

  return public.get_role_permission_center();
end;
$$;

create or replace function public.reset_role_permission_override(
  p_scope text,
  p_role_code text,
  p_permission_code text,
  p_object_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_actor_role text := public.current_user_role();
  v_before boolean;
  v_after boolean;
  v_actor_name text := '';
begin
  if v_company_id is null or not public.can_manage_role_permissions() then
    raise exception 'Недостаточно прав для управления матрицей ролей';
  end if;
  if p_scope not in ('company','object') then
    raise exception 'Неизвестная область настройки';
  end if;
  if v_actor_role = 'admin' and p_role_code in ('admin','developer','owner') then
    raise exception 'Администратор не может изменять системные роли';
  end if;

  if p_scope = 'object' then
    if p_object_id is null or not exists (
      select 1 from public.objects item
       where item.id = p_object_id and item.company_id = v_company_id
    ) then
      raise exception 'Объект не найден';
    end if;
  else
    p_object_id := null;
  end if;

  v_before := public.role_permission_effective(
    v_company_id,
    case when p_scope = 'object' then p_object_id else null end,
    p_role_code,
    p_permission_code
  );

  if p_scope = 'company' then
    delete from public.company_role_permission_overrides
     where company_id = v_company_id
       and role_code = p_role_code
       and permission_code = p_permission_code;
  else
    delete from public.object_role_permission_overrides
     where company_id = v_company_id
       and object_id = p_object_id
       and role_code = p_role_code
       and permission_code = p_permission_code;
  end if;

  v_after := public.role_permission_effective(
    v_company_id,
    case when p_scope = 'object' then p_object_id else null end,
    p_role_code,
    p_permission_code
  );

  select coalesce(
    nullif(btrim(item.full_name), ''),
    nullif(btrim(item.email), ''),
    'Пользователь'
  ) into v_actor_name
  from public.user_profiles item
  where item.id = auth.uid();

  insert into public.role_permission_audit(
    company_id, object_id, scope, role_code, permission_code,
    action, before_allowed, after_allowed, actor_user_id, actor_name
  ) values (
    v_company_id, p_object_id, p_scope, p_role_code, p_permission_code,
    'reset', v_before, v_after, auth.uid(), coalesce(v_actor_name, 'Пользователь')
  );

  return public.get_role_permission_center();
end;
$$;

revoke all on function public.role_permission_effective(uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.current_user_has_permission(text) from public, anon;
revoke all on function public.current_user_has_object_permission(text, uuid) from public, anon;
revoke all on function public.current_user_has_object_permission_by_name(text, text) from public, anon;
revoke all on function public.current_user_has_task_permission(text, uuid) from public, anon;
revoke all on function public.current_user_has_payment_permission(text, uuid) from public, anon;
revoke all on function public.can_manage_role_permissions() from public, anon;
revoke all on function public.get_role_permission_center() from public, anon;
revoke all on function public.save_role_permission_override(text, text, text, boolean, uuid) from public, anon;
revoke all on function public.reset_role_permission_override(text, text, text, uuid) from public, anon;

grant execute on function public.current_user_has_permission(text) to authenticated;
grant execute on function public.current_user_has_object_permission(text, uuid) to authenticated;
grant execute on function public.current_user_has_object_permission_by_name(text, text) to authenticated;
grant execute on function public.current_user_has_task_permission(text, uuid) to authenticated;
grant execute on function public.current_user_has_payment_permission(text, uuid) to authenticated;
grant execute on function public.can_manage_role_permissions() to authenticated;
grant execute on function public.get_role_permission_center() to authenticated;
grant execute on function public.save_role_permission_override(text, text, text, boolean, uuid) to authenticated;
grant execute on function public.reset_role_permission_override(text, text, text, uuid) to authenticated;
