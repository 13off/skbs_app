from pathlib import Path


def replace_between(path: str, start_marker: str, end_marker: str, replacement: str) -> None:
    p = Path(path)
    text = p.read_text(encoding='utf-8')
    start = text.index(start_marker)
    end = text.index(end_marker, start)
    p.write_text(text[:start] + replacement + text[end:], encoding='utf-8')


# 1. Reminder model: exact personal date/time instead of event-relative offsets.
models_path = Path('lib/features/recruitment/models/recruitment_flight_models.dart')
models = models_path.read_text(encoding='utf-8')
model_start = models.index('class RecruitmentFlightReminder {')
model_end = models.index('\nclass RecruitmentFlight {', model_start)
new_model = '''class RecruitmentFlightReminder {
  final String id;
  final String companyId;
  final String flightId;
  final DateTime remindAt;
  final DateTime? sentAt;

  const RecruitmentFlightReminder({
    this.id = '',
    this.companyId = '',
    this.flightId = '',
    required this.remindAt,
    this.sentAt,
  });

  bool get isSent => sentAt != null;

  String get label {
    final local = remindAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} · $hour:$minute';
  }

  Map<String, dynamic> toPayload() => <String, dynamic>{
    'remind_at': remindAt.toUtc().toIso8601String(),
  };

  factory RecruitmentFlightReminder.fromMap(Map<String, dynamic> map) {
    DateTime? optionalDate(dynamic value) {
      final text = value?.toString().trim() ?? '';
      return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
    }

    return RecruitmentFlightReminder(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      flightId: map['flight_id']?.toString() ?? '',
      remindAt:
          optionalDate(map['remind_at']) ??
          optionalDate(map['created_at']) ??
          DateTime.now(),
      sentAt: optionalDate(map['sent_at']),
    );
  }
}
'''
models_path.write_text(models[:model_start] + new_model + models[model_end:], encoding='utf-8')

# 2. Repository validation becomes exact personal timestamp validation.
repo_path = Path('lib/features/recruitment/data/recruitment_flight_repository.dart')
repo = repo_path.read_text(encoding='utf-8')
validation_start = repo.index('    final reminderKeys = <String>{};')
validation_end = repo.index('    final newAttachmentCount =', validation_start)
new_validation = '''    final reminderKeys = <String>{};
    for (final reminder in reminders) {
      final local = reminder.remindAt.toLocal();
      final normalized = DateTime(
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      );
      final key = normalized.toUtc().toIso8601String();
      if (!reminderKeys.add(key)) {
        throw Exception('Уведомление на эту дату и время уже добавлено');
      }
      if (!reminder.isSent && !normalized.isAfter(DateTime.now())) {
        throw Exception('Время одного из уведомлений уже прошло');
      }
    }

'''
repo = repo[:validation_start] + new_validation + repo[validation_end:]

# Stop client-side polling/employee delivery for scheduled reminders. The DB cron now owns delivery.
calendar_dispatch = '''    if (dispatchReminders) {
      unawaited(
        dispatchDueReminders(candidates: candidates).catchError((_) {}),
      );
    }
'''
repo = repo.replace(calendar_dispatch, '')
repo_path.write_text(repo, encoding='utf-8')

# 3. Flight UI: preserve arrival field, simplify reminder to date -> time, remove employee reminder action.
ui_path = Path('lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart')
ui = ui_path.read_text(encoding='utf-8')
ui = ui.replace('  final Set<String> reminderBusyIds = <String>{};\n', '')

send_start = ui.index('  Future<void> sendReminder(RecruitmentFlightEntry entry) async {')
send_end = ui.index('  Future<void> changeStatus(', send_start)
ui = ui[:send_start] + ui[send_end:]

ui = ui.replace('    final reminderBusy = reminderBusyIds.contains(flight.id);\n', '')
ui = ui.replace("      subtitle: 'Билеты, маршруты и напоминания сотрудникам',", "      subtitle: 'Билеты, маршруты и ваши уведомления',")
ui = ui.replace(
    "                    'После сохранения билетов вылет появляется в календаре. Система создаёт напоминания за сутки и за 3 часа, а HR может отправить напоминание вручную.',",
    "                    'После сохранения билетов вылет появляется в календаре. При необходимости добавьте точную дату и время личного уведомления для себя.',",
)

legacy_chips = '''                if (flight.remindDayBefore)
                  const _FlightChip(
                    icon: Icons.notifications_active_outlined,
                    text: 'За сутки',
                  ),
                if (flight.remindThreeHours)
                  const _FlightChip(
                    icon: Icons.alarm_outlined,
                    text: 'За 3 часа',
                  ),
'''
ui = ui.replace(legacy_chips, '')

employee_button = '''            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: reminderBusy || flight.isCancelled || flight.isCompleted
                  ? null
                  : () => sendReminder(entry),
              icon: reminderBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text('Напомнить сотруднику'),
            ),
'''
ui = ui.replace(employee_button, '')

add_start = ui.index('  Future<void> addReminder() async {')
add_end = ui.index('  Widget buildRemindersCard() {', add_start)
new_add = '''  Future<void> addReminder() async {
    final now = DateTime.now();
    final initial = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(hours: 1));
    final value = await chooseDateTime(initial);
    if (value == null || !mounted) return;

    final normalized = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
    if (!normalized.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите будущие дату и время уведомления')),
      );
      return;
    }
    final duplicate = reminders.any((item) {
      final current = item.remindAt.toLocal();
      return current.year == normalized.year &&
          current.month == normalized.month &&
          current.day == normalized.day &&
          current.hour == normalized.hour &&
          current.minute == normalized.minute;
    });
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Уведомление на это время уже добавлено')),
      );
      return;
    }
    setState(
      () => reminders.add(RecruitmentFlightReminder(remindAt: normalized)),
    );
  }

'''
ui = ui[:add_start] + new_add + ui[add_end:]
ui = ui.replace(
    "                ? 'Уведомления не добавлены. Можно поставить несколько напоминаний перед отправлением или прибытием.'",
    "                ? 'Добавьте дату и время, когда нужно напомнить вам об этом вылете.'",
)
old_icon = '''                    Icon(
                      reminder.isArrival
                          ? Icons.flight_land_rounded
                          : Icons.flight_takeoff_rounded,
                      color: AppAdaptivePalette.accentStrong,
                    ),
'''
new_icon = '''                    Icon(
                      Icons.notifications_active_outlined,
                      color: AppAdaptivePalette.accentStrong,
                    ),
'''
ui = ui.replace(old_icon, new_icon)
ui_path.write_text(ui, encoding='utf-8')

# 4. Migration: absolute, owner-scoped reminders + minute cron delivery to the creating user.
migration_path = Path('supabase/migrations/20260819170000_personal_flight_reminder_datetime.sql')
migration_path.write_text(r'''-- Personal flight reminders use an exact timestamp chosen by the current user.
-- Arrival/departure fields on recruitment_flights remain unchanged.

alter table public.recruitment_flight_reminders
  add column if not exists remind_at timestamptz;
alter table public.recruitment_flight_reminders
  add column if not exists target_user_id uuid references auth.users(id) on delete cascade;

-- Rows created by the previous automatic 24h/3h employee-reminder model are intentionally
-- removed: the product now creates reminders only when a user explicitly picks date/time.
delete from public.recruitment_flight_reminders
where remind_at is null or target_user_id is null;

alter table public.recruitment_flight_reminders
  alter column remind_at set not null;
alter table public.recruitment_flight_reminders
  alter column target_user_id set not null;

alter table public.recruitment_flight_reminders
  drop constraint if exists recruitment_flight_reminders_unique;
drop index if exists public.recruitment_flight_reminders_due_idx;

create unique index if not exists recruitment_flight_reminders_personal_time_uidx
  on public.recruitment_flight_reminders(flight_id, target_user_id, remind_at);
create index if not exists recruitment_flight_reminders_personal_due_idx
  on public.recruitment_flight_reminders(remind_at, sent_at)
  where sent_at is null;

-- A user sees only their own reminders. Writes stay behind the scoped RPC below.
drop policy if exists recruitment_flight_reminders_select
  on public.recruitment_flight_reminders;
create policy recruitment_flight_reminders_select
  on public.recruitment_flight_reminders
  for select to authenticated
  using (
    company_id = (select public.current_user_company_id())
    and target_user_id = (select auth.uid())
    and public.current_user_has_permission('recruitment.applications.view')
  );

create or replace function public.replace_recruitment_flight_reminders(
  p_flight_id uuid,
  p_reminders jsonb default '[]'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company_id uuid := public.current_user_company_id();
  v_user_id uuid := (select auth.uid());
  v_item jsonb;
  v_remind_at timestamptz;
  v_event_kind text;
  v_offset_minutes integer;
begin
  if v_user_id is null or v_company_id is null then
    raise exception 'Нет активной сессии компании';
  end if;
  if not public.current_user_has_permission('recruitment.applications.edit') then
    raise exception 'Недостаточно прав для изменения уведомлений';
  end if;
  if not exists (
    select 1
    from public.recruitment_flights flight
    where flight.id = p_flight_id
      and flight.company_id = v_company_id
  ) then
    raise exception 'Вылет не найден в выбранной компании';
  end if;
  if jsonb_typeof(coalesce(p_reminders, '[]'::jsonb)) <> 'array' then
    raise exception 'Некорректный список уведомлений';
  end if;
  if jsonb_array_length(coalesce(p_reminders, '[]'::jsonb)) > 20 then
    raise exception 'Для одного вылета можно добавить не больше 20 уведомлений';
  end if;

  -- Submitted timestamps are the full source of truth for the current user's reminders.
  delete from public.recruitment_flight_reminders reminder
  where reminder.company_id = v_company_id
    and reminder.flight_id = p_flight_id
    and reminder.target_user_id = v_user_id
    and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb)) item
      where item ? 'remind_at'
        and date_trunc('minute', (item->>'remind_at')::timestamptz)
          = date_trunc('minute', reminder.remind_at)
    );

  for v_item in
    select value from jsonb_array_elements(coalesce(p_reminders, '[]'::jsonb))
  loop
    if v_item ? 'remind_at' then
      begin
        v_remind_at := date_trunc('minute', (v_item->>'remind_at')::timestamptz);
      exception when others then
        raise exception 'Некорректные дата или время уведомления';
      end;
    else
      -- Compatibility for older installed clients during the rollout.
      v_event_kind := case when v_item->>'event_kind' = 'arrival'
        then 'arrival' else 'departure' end;
      begin
        v_offset_minutes := (v_item->>'offset_minutes')::integer;
      exception when others then
        raise exception 'Некорректное время уведомления';
      end;
      select date_trunc(
        'minute',
        (case when v_event_kind = 'arrival' then flight.arrival_at else flight.departure_at end)
          - make_interval(mins => greatest(v_offset_minutes, 0))
      )
      into v_remind_at
      from public.recruitment_flights flight
      where flight.id = p_flight_id
        and flight.company_id = v_company_id;
    end if;

    if v_remind_at is null then
      raise exception 'Укажите дату и время уведомления';
    end if;
    if v_remind_at <= now() and not exists (
      select 1
      from public.recruitment_flight_reminders reminder
      where reminder.company_id = v_company_id
        and reminder.flight_id = p_flight_id
        and reminder.target_user_id = v_user_id
        and reminder.remind_at = v_remind_at
        and reminder.sent_at is not null
    ) then
      raise exception 'Дата и время уведомления уже прошли';
    end if;

    insert into public.recruitment_flight_reminders(
      company_id,
      flight_id,
      event_kind,
      offset_minutes,
      remind_at,
      target_user_id,
      created_by,
      updated_by
    ) values (
      v_company_id,
      p_flight_id,
      'departure',
      0,
      v_remind_at,
      v_user_id,
      v_user_id,
      v_user_id
    )
    on conflict (flight_id, target_user_id, remind_at) do update
      set updated_by = excluded.updated_by,
          updated_at = now();
  end loop;

  update public.recruitment_flights
  set remind_day_before = false,
      remind_three_hours = false,
      updated_by = v_user_id,
      updated_at = now()
  where id = p_flight_id and company_id = v_company_id;
end;
$$;

revoke all on function public.replace_recruitment_flight_reminders(uuid,jsonb)
  from public, anon;
grant execute on function public.replace_recruitment_flight_reminders(uuid,jsonb)
  to authenticated;

create or replace function private.process_due_recruitment_flight_personal_reminders()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_due record;
  v_body text;
  v_departure_local timestamp;
  v_arrival_local timestamp;
  v_count integer := 0;
begin
  for v_due in
    select
      reminder.id as reminder_id,
      reminder.company_id,
      reminder.target_user_id,
      reminder.remind_at,
      flight.id as flight_id,
      flight.origin,
      flight.destination,
      flight.flight_number,
      flight.departure_at,
      flight.arrival_at,
      coalesce(application.full_name, 'Сотрудник') as full_name,
      coalesce(object_row.name, '') as object_name
    from public.recruitment_flight_reminders reminder
    join public.recruitment_flights flight
      on flight.company_id = reminder.company_id
     and flight.id = reminder.flight_id
    left join public.recruitment_applications application
      on application.company_id = flight.company_id
     and application.id = flight.application_id
    left join public.objects object_row
      on object_row.company_id = flight.company_id
     and object_row.id = flight.object_id
    where reminder.sent_at is null
      and reminder.remind_at <= now()
      and flight.status <> 'cancelled'
    order by reminder.remind_at, reminder.id
    for update of reminder skip locked
  loop
    v_departure_local := v_due.departure_at at time zone 'Europe/Moscow';
    v_arrival_local := case when v_due.arrival_at is null
      then null else v_due.arrival_at at time zone 'Europe/Moscow' end;

    v_body := v_due.full_name || '. ' ||
      btrim(v_due.origin) || ' → ' || btrim(v_due.destination) || '. ' ||
      'Вылет ' || to_char(v_departure_local, 'DD.MM.YYYY в HH24:MI') || '.' ||
      case when v_arrival_local is null then ''
        else ' Прибытие ' || to_char(v_arrival_local, 'DD.MM.YYYY в HH24:MI') || '.' end ||
      case when btrim(v_due.flight_number) = '' then ''
        else ' Рейс ' || btrim(v_due.flight_number) || '.' end;

    insert into public.app_notifications(
      title,
      body,
      actor_user_id,
      actor_name,
      actor_email,
      object_name,
      entity_type,
      entity_id,
      company_id,
      target_user_id,
      target_role,
      requires_action,
      due_at,
      priority,
      source_role,
      is_push_only,
      push_requested
    ) values (
      'Напоминание о вылете',
      v_body,
      null,
      'AppСтрой',
      '',
      v_due.object_name,
      'recruitment_flight_reminder',
      v_due.flight_id::text,
      v_due.company_id,
      v_due.target_user_id,
      null,
      false,
      v_due.remind_at,
      'normal',
      'hr',
      false,
      true
    );

    update public.recruitment_flight_reminders
    set sent_at = now(), updated_at = now()
    where id = v_due.reminder_id and sent_at is null;

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

revoke all on function private.process_due_recruitment_flight_personal_reminders()
  from public, anon, authenticated;

-- Old clients may still invoke this public dispatcher while caches roll over.
-- It intentionally returns no employee-facing rows; scheduled delivery is cron-owned.
create or replace function public.dispatch_due_recruitment_flight_reminders()
returns setof jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  return;
end;
$$;

revoke all on function public.dispatch_due_recruitment_flight_reminders()
  from public, anon;
grant execute on function public.dispatch_due_recruitment_flight_reminders()
  to authenticated;

-- Exact reminders are checked every minute. Push delivery is queued by the existing
-- app_notifications trigger, so the creator receives both in-app and push delivery.
do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id
  from cron.job
  where jobname = 'appstroy-flight-personal-reminders';

  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;

  perform cron.schedule(
    'appstroy-flight-personal-reminders',
    '* * * * *',
    'select private.process_due_recruitment_flight_personal_reminders();'
  );
end;
$$;
''', encoding='utf-8')

# 5. Regression contract for the simplified UX and personal scheduling.
test_path = Path('test/flight_reminders_timesheet_period_test.dart')
test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/recruitment/models/recruitment_flight_models.dart';

void main() {
  test('flight reminder stores exact chosen date and time', () {
    final reminder = RecruitmentFlightReminder(
      remindAt: DateTime(2026, 8, 25, 18, 30),
    );

    expect(reminder.label, '25.08.2026 · 18:30');
    expect(
      reminder.toPayload()['remind_at'],
      reminder.remindAt.toUtc().toIso8601String(),
    );
  });

  test('flight editor asks only for reminder date and time', () {
    final source = File(
      'lib/features/recruitment/presentation/recruitment_flight_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'Добавить уведомление'"));
    expect(source, contains('final value = await chooseDateTime(initial);'));
    expect(source, contains('RecruitmentFlightReminder(remindAt: normalized)'));
    expect(source, isNot(contains("labelText: 'Событие'")));
    expect(source, isNot(contains("labelText: 'Когда напомнить'")));
    expect(source, isNot(contains("'За 15 минут'")));
    expect(source, isNot(contains("'За 3 часа'")));
    expect(source, isNot(contains("'За 24 часа'")));
    expect(source, isNot(contains("'Свой вариант'")));
    expect(source, isNot(contains("'Напомнить сотруднику'")));
    expect(source, contains('Future<void> chooseArrival() async'));
    expect(source, contains("'Убрать время прибытия'"));
  });

  test('personal flight reminder is owner scoped and cron scheduled', () {
    final repository = File(
      'lib/features/recruitment/data/recruitment_flight_repository.dart',
    ).readAsStringSync();
    final migration = File(
      'supabase/migrations/20260819170000_personal_flight_reminder_datetime.sql',
    ).readAsStringSync();

    expect(repository, contains("from('recruitment_flight_reminders')"));
    expect(repository, contains("'replace_recruitment_flight_reminders'"));
    expect(repository, contains('reminder.remindAt'));
    expect(migration, contains('remind_at timestamptz'));
    expect(migration, contains('target_user_id uuid references auth.users(id)'));
    expect(migration, contains('target_user_id = (select auth.uid())'));
    expect(migration, contains('process_due_recruitment_flight_personal_reminders'));
    expect(migration, contains("'appstroy-flight-personal-reminders'"));
    expect(migration, contains("'* * * * *'"));
    expect(migration, contains("'Напоминание о вылете'"));
    expect(migration, contains("'recruitment_flight_reminder'"));
    expect(migration, contains('v_due.target_user_id'));
  });

  test('individual timesheet supports multiple months, exact range and balance', () {
    final screen = File('lib/screens/employee_timesheet_screen.dart')
        .readAsStringSync();
    final repository = File('lib/data/attendance_repository.dart')
        .readAsStringSync();

    expect(screen, contains('_EmployeeTimesheetPeriodMode.months'));
    expect(screen, contains('_EmployeeTimesheetPeriodMode.dates'));
    expect(screen, contains('Set<DateTime> selectedMonths'));
    expect(screen, contains('showDateRangePicker'));
    expect(screen, contains("label: 'Остаток за выбранное'"));
    expect(screen, contains("return '\$text рублей';"));
    expect(repository, contains('fetchTimesheetForEmployeePeriod'));
    expect(repository, contains(".gte('payment_date', dateKey(cleanStart))"));
    expect(repository, contains(".lte('payment_date', dateKey(cleanEnd))"));
  });
}
''', encoding='utf-8')

# The patcher/workflow are one-shot and must not land in the PR.
Path('.github/scripts/patch_personal_flight_reminders.py').unlink(missing_ok=True)
Path('.github/workflows/patch-personal-flight-reminders.yml').unlink(missing_ok=True)
