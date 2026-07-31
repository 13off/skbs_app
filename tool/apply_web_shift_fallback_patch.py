from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding='utf-8')
    if old not in text:
        raise SystemExit(f'Expected fragment not found in {path}: {old[:120]!r}')
    file.write_text(text.replace(old, new, 1), encoding='utf-8')


replace_once(
    'lib/features/employee/data/employee_shift_runtime.dart',
    "  Future<EmployeeWorkShift> start(String employeeId) async {\n",
    "  Future<void> reload(String employeeId) async {\n"
    "    final cleanEmployeeId = employeeId.trim();\n"
    "    if (cleanEmployeeId.isEmpty) return;\n"
    "    await _stopPositionStream();\n"
    "    _resetMemory();\n"
    "    _boundEmployeeId = '';\n"
    "    state.value = const EmployeeWorkDaySnapshot.idle();\n"
    "    await bind(cleanEmployeeId);\n"
    "  }\n\n"
    "  Future<EmployeeWorkShift> start(String employeeId) async {\n",
)
replace_once(
    'lib/features/employee/data/employee_shift_action_repository.dart',
    "  final double startLatitude;\n  final double startLongitude;\n",
    "  final double? startLatitude;\n  final double? startLongitude;\n",
)
replace_once(
    'lib/features/employee/data/employee_shift_action_repository.dart',
    "      startLatitude: _number(json['start_latitude']),\n      startLongitude: _number(json['start_longitude']),\n",
    "      startLatitude: _nullableNumber(json['start_latitude']),\n      startLongitude: _nullableNumber(json['start_longitude']),\n",
)

Path('lib/features/employee/data/employee_shift_web_fallback_repository.dart').write_text(
    """import 'package:supabase_flutter/supabase_flutter.dart';

import 'employee_shift_action_repository.dart';

class EmployeeShiftWebFallbackRepository {
  EmployeeShiftWebFallbackRepository._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<EmployeeWorkShift> startWithoutLocation({
    required String employeeId,
  }) async {
    final raw = await _client.rpc(
      'start_employee_shift_without_location',
      params: <String, dynamic>{
        'p_employee_id': employeeId.trim(),
        'p_work_date': _dateKey(DateTime.now()),
      },
    );
    final data = _map(raw);
    final shift = _map(data['active_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был начат');
    return EmployeeWorkShift.fromJson(shift);
  }

  static Future<EmployeeWorkShift> finishWithoutLocation({
    required String employeeId,
  }) async {
    final raw = await _client.rpc(
      'finish_employee_shift_without_location',
      params: <String, dynamic>{'p_employee_id': employeeId.trim()},
    );
    final data = _map(raw);
    final shift = _map(data['completed_shift']);
    if (shift.isEmpty) throw Exception('Рабочий день не был завершён');
    return EmployeeWorkShift.fromJson(shift);
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
""",
    encoding='utf-8',
)

replace_once(
    'lib/features/employee/presentation/employee_home_screen.dart',
    "import '../data/employee_shift_runtime.dart';\n",
    "import '../data/employee_shift_runtime.dart';\n"
    "import '../data/employee_shift_web_fallback_repository.dart';\n",
)
replace_once(
    'lib/features/employee/presentation/employee_home_screen.dart',
    """    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      if (kIsWeb) {
        await openWebLocationDialog(error.message);
      } else {
        message(error.message);
        if (error.openSettingsRequired) {
          await openSettingsDialog(error.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
""",
    """    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      if (kIsWeb) {
        await startWebWithoutLocation(employeeId);
      } else {
        message(error.message);
        if (error.openSettingsRequired) {
          await openSettingsDialog(error.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      if (kIsWeb && isEmployeeLocationError(error)) {
        await startWebWithoutLocation(employeeId);
      } else {
        message(employeeLocationErrorMessage(error));
      }
""",
)
replace_once(
    'lib/features/employee/presentation/employee_home_screen.dart',
    """    } catch (error) {
      if (mounted) message(employeeLocationErrorMessage(error));
    } finally {
""",
    """    } catch (error) {
      if (!mounted) return;
      if (kIsWeb && isEmployeeLocationError(error)) {
        await finishWebWithoutLocation(widget.selectedEmployeeId.value);
      } else {
        message(employeeLocationErrorMessage(error));
      }
    } finally {
""",
)
replace_once(
    'lib/features/employee/presentation/employee_home_screen.dart',
    "  Future<void> openSettingsDialog(String text) async {\n",
    """  Future<void> startWebWithoutLocation(String employeeId) async {
    try {
      await EmployeeShiftWebFallbackRepository.startWithoutLocation(
        employeeId: employeeId,
      );
      await runtime.reload(employeeId);
      if (mounted) message('Рабочий день начат');
    } catch (error) {
      if (mounted) message(cleanError(error));
    }
  }

  Future<void> finishWebWithoutLocation(String employeeId) async {
    try {
      await EmployeeShiftWebFallbackRepository.finishWithoutLocation(
        employeeId: employeeId,
      );
      await runtime.reload(employeeId);
      if (mounted) message('Рабочий день завершён');
    } catch (error) {
      if (mounted) message(cleanError(error));
    }
  }

  Future<void> openSettingsDialog(String text) async {
""",
)
replace_once(
    'lib/features/employee/presentation/employee_home_screen.dart',
    """  Future<void> openWebLocationDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Не удалось получить геопозицию'),
        content: Text(text),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

""",
    "",
)

Path('supabase/migrations/20260731150500_allow_web_shift_without_initial_location.sql').write_text(
    r"""begin;

alter table public.employee_work_shifts
  alter column start_latitude drop not null,
  alter column start_longitude drop not null,
  alter column start_accuracy_m drop not null,
  alter column start_distance_m drop not null;

create or replace function public.start_employee_shift_without_location(
  p_employee_id uuid,
  p_work_date date default current_date
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_person_id uuid;
  v_employee public.employees%rowtype;
  v_shift public.employee_work_shifts%rowtype;
begin
  if v_user_id is null then raise exception 'Требуется повторный вход'; end if;

  select up.active_company_id, up.role into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id and up.is_active = true;

  if v_company_id is null or v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception 'Рабочие действия недоступны';
  end if;

  if v_role = 'employee' then
    select eal.person_id into v_person_id
    from public.employee_account_links eal
    where eal.company_id = v_company_id and eal.user_id = v_user_id and eal.is_active = true
    limit 1;
    if v_person_id is null then raise exception 'Рабочая карточка не привязана'; end if;

    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.person_id = v_person_id
      and e.is_active = true and e.archived_at is null
    order by e.updated_at desc limit 1;
    if v_employee.id is null or v_employee.id <> p_employee_id then
      raise exception 'Нельзя выполнять действия от имени другого сотрудника';
    end if;
  else
    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.id = p_employee_id
      and e.is_active = true and e.archived_at is null
    limit 1;
  end if;

  if v_employee.id is null then raise exception 'Сотрудник не найден'; end if;
  if v_employee.object_id is null then raise exception 'У сотрудника не указан объект'; end if;

  select s.* into v_shift
  from public.employee_work_shifts s
  where s.company_id = v_company_id and s.employee_id = v_employee.id and s.status = 'active'
  limit 1;

  if v_shift.id is null then
    insert into public.employee_work_shifts (
      company_id, employee_id, task_id, object_id, work_date, status, started_at,
      start_latitude, start_longitude, start_accuracy_m, start_distance_m,
      permission_scope, tracking_mode, route_point_count, last_point_at, started_by
    ) values (
      v_company_id, v_employee.id, null, v_employee.object_id,
      coalesce(p_work_date, current_date), 'active', now(),
      null, null, null, null, 'unavailable', 'web_foreground', 0, null, v_user_id
    ) returning * into v_shift;
  end if;

  return jsonb_build_object('ok', true, 'active_shift', to_jsonb(v_shift));
end;
$$;

create or replace function public.finish_employee_shift_without_location(
  p_employee_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_company_id uuid;
  v_role text;
  v_person_id uuid;
  v_employee public.employees%rowtype;
  v_shift public.employee_work_shifts%rowtype;
begin
  if v_user_id is null then raise exception 'Требуется повторный вход'; end if;

  select up.active_company_id, up.role into v_company_id, v_role
  from public.user_profiles up
  where up.id = v_user_id and up.is_active = true;

  if v_company_id is null or v_role not in ('employee', 'admin', 'developer', 'foreman') then
    raise exception 'Рабочие действия недоступны';
  end if;

  if v_role = 'employee' then
    select eal.person_id into v_person_id
    from public.employee_account_links eal
    where eal.company_id = v_company_id and eal.user_id = v_user_id and eal.is_active = true
    limit 1;

    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.person_id = v_person_id
      and e.is_active = true and e.archived_at is null
    order by e.updated_at desc limit 1;
    if v_employee.id is null or v_employee.id <> p_employee_id then
      raise exception 'Нельзя выполнять действия от имени другого сотрудника';
    end if;
  else
    select e.* into v_employee
    from public.employees e
    where e.company_id = v_company_id and e.id = p_employee_id
      and e.is_active = true and e.archived_at is null
    limit 1;
  end if;

  if v_employee.id is null then raise exception 'Сотрудник не найден'; end if;

  update public.employee_work_shifts s
     set status = 'completed', ended_at = now(), ended_by = v_user_id, updated_at = now()
   where s.company_id = v_company_id and s.employee_id = v_employee.id and s.status = 'active'
  returning s.* into v_shift;

  if v_shift.id is null then raise exception 'Рабочий день не начат'; end if;
  return jsonb_build_object('ok', true, 'completed_shift', to_jsonb(v_shift));
end;
$$;

revoke all on function public.start_employee_shift_without_location(uuid, date) from public;
revoke all on function public.finish_employee_shift_without_location(uuid) from public;
grant execute on function public.start_employee_shift_without_location(uuid, date) to authenticated;
grant execute on function public.finish_employee_shift_without_location(uuid) to authenticated;

comment on function public.start_employee_shift_without_location(uuid, date) is
  'Начинает рабочий день в web/PWA без синтетической координаты, если WebKit не отдал геопозицию.';
comment on function public.finish_employee_shift_without_location(uuid) is
  'Завершает web/PWA рабочий день без синтетической конечной координаты.';

commit;
""",
    encoding='utf-8',
)

Path('test/employee_web_shift_fallback_contract_test.dart').write_text(
    """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const homePath =
      'lib/features/employee/presentation/employee_home_screen.dart';
  const runtimePath =
      'lib/features/employee/data/employee_shift_runtime.dart';
  const fallbackPath =
      'lib/features/employee/data/employee_shift_web_fallback_repository.dart';
  const migrationPath =
      'supabase/migrations/20260731150500_allow_web_shift_without_initial_location.sql';

  test('PWA starts and finishes the workday without blocking on WebKit GPS', () {
    final home = File(homePath).readAsStringSync();
    final fallback = File(fallbackPath).readAsStringSync();

    expect(home, contains('startWebWithoutLocation(employeeId)'));
    expect(home, contains('finishWebWithoutLocation'));
    expect(home, contains('await runtime.reload(employeeId)'));
    expect(fallback, contains('start_employee_shift_without_location'));
    expect(fallback, contains('finish_employee_shift_without_location'));
  });

  test('native Android still requires a real location and always permission', () {
    final runtime = File(runtimePath).readAsStringSync();

    expect(runtime, contains('Geolocator.getCurrentPosition'));
    expect(runtime, contains('permission != LocationPermission.always'));
    expect(runtime, contains("trackingMode: kIsWeb ? 'web_foreground' : 'native_background'"));
  });

  test('web fallback writes null, never zero or demo coordinates', () {
    final migration = File(migrationPath).readAsStringSync();

    expect(migration, contains('start_latitude drop not null'));
    expect(migration, contains("'unavailable'"));
    expect(migration, contains("'web_foreground'"));
    expect(migration, isNot(contains('start_latitude,\\n      0')));
    expect(migration, isNot(contains('start_longitude,\\n      0')));
  });
}
""",
    encoding='utf-8',
)

contract = Path('test/employee_start_location_web_contract_test.dart')
contract_text = contract.read_text(encoding='utf-8')
contract_text = contract_text.replace(
    "    expect(home, contains('openWebLocationDialog'));\n",
    "    expect(home, contains('startWebWithoutLocation(employeeId)'));\n",
)
contract_text = contract_text.replace(
    "  test('ошибка геопозиции не содержит обучающей инструкции', () {\n",
    "  test('ошибка геопозиции не содержит обучающей инструкции и не блокирует смену', () {\n",
)
contract_text = contract_text.replace(
    "    expect(home, contains('content: Text(text)'));\n",
    "    expect(home, contains('EmployeeShiftWebFallbackRepository'));\n",
)
contract.write_text(contract_text, encoding='utf-8')

Path('tool/apply_web_shift_fallback_patch.py').unlink()
Path('.github/workflows/pr-check.yml').write_text(
    Path('/tmp/pr-check-main.yml').read_text(encoding='utf-8'),
    encoding='utf-8',
)
